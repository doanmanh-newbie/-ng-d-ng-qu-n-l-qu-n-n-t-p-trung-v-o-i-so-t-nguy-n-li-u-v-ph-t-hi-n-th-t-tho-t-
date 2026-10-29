-- =====================================================================
-- Fore · 006_waste_report.sql · Báo cáo hao hụt cho chủ (CHỈ CẢNH BÁO, không chặn)
--
-- Vì sao cần: hao hụt "có lý do" được TRỪ khỏi chênh lệch đối soát (cột justified_waste ở
-- reconcile_shift). Nếu không có báo cáo này, có thể ghi "đổ bỏ" để che việc lấy trộm.
-- Báo cáo cho chủ thấy: hao hụt từng nguyên liệu theo từng LOẠI, chiếm bao nhiêu % so với
-- lượng dùng lý thuyết, và cờ cảnh báo nếu vượt waste_warn_pct (con số trong app_settings).
-- Hệ thống không quyết định thay chủ: chỉ hiện số và cờ để chủ tự xem lại.
--
-- Chạy SAU 005_cash_reconcile.sql.
-- =====================================================================

-- Chi tiết từng lần ghi hao hụt, kèm tên người nhập (chủ đọc được nhờ RLS của bảng waste_logs)
create or replace view v_waste_detail with (security_invoker = true) as
select w.shift_id, w.entered_at, i.name as ingredient_name, i.unit,
       w.reason_type, t.label_vi as reason_label, w.qty, w.reason as note,
       s.full_name as entered_by_name
  from waste_logs w
  join ingredients i on i.id = w.ingredient_id
  join waste_types t on t.code = w.reason_type and t.shop_id = w.shop_id
  left join staff s on s.id = w.entered_by;
grant select on v_waste_detail to authenticated;

-- Báo cáo theo ca: mỗi dòng là (nguyên liệu, loại hao hụt)
--   waste_pct_total = TỔNG hao hụt của nguyên liệu đó (mọi loại) ÷ lượng dùng lý thuyết × 100
--   flag = 'warn' nếu waste_pct_total >= waste_warn_pct, hoặc không bán gì mà vẫn có hao hụt; còn lại 'ok'
create or replace function waste_report(p_shift uuid)
returns table (
  ingredient_id     uuid,
  ingredient_name   text,
  unit              text,
  reason_type       text,
  reason_label      text,
  entries           integer,   -- số lần ghi
  qty               integer,   -- tổng lượng của loại này
  waste_total       integer,   -- tổng hao hụt của nguyên liệu (mọi loại)
  theoretical_used  integer,
  waste_pct_total   numeric,
  flag              text       -- ok | warn
)
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_warn int;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;
  v_warn := _setting('waste_warn_pct', 10, v_shop);

  return query
  with w as (
    -- Lượng lấy từ SỔ KHO (gồm cả dòng điều chỉnh của 007) để khớp với reconcile_shift
    select wl.ingredient_id as iid, wl.reason_type as rtype,
           count(distinct wl.id) as n, -sum(sl.qty_delta) as q
      from waste_logs wl
      join stock_ledger sl on sl.kind = 'waste' and sl.ref_id = wl.id
     where wl.shift_id = p_shift
     group by 1, 2
  ),
  tot as (select w.iid, sum(w.q) as q from w group by 1),
  th as (
    select s.ingredient_id as iid, -sum(s.qty_delta) as q
      from stock_ledger s
     where s.shift_id = p_shift and s.kind in ('sale', 'void_sale') group by 1
  )
  select i.id, i.name, i.unit, w.rtype, t.label_vi,
         w.n::integer, w.q::integer, tot.q::integer, coalesce(th.q, 0)::integer,
         round(tot.q * 100.0 / nullif(th.q, 0), 1),
         case when coalesce(th.q, 0) = 0 then 'warn'
              when tot.q * 100.0 / th.q >= v_warn then 'warn'
              else 'ok' end
    from w
    join tot on tot.iid = w.iid
    join ingredients i on i.id = w.iid
    join waste_types t on t.code = w.rtype and t.shop_id = v_shop
    left join th on th.iid = w.iid
   order by (case when coalesce(th.q, 0) = 0 or tot.q * 100.0 / th.q >= v_warn then 0 else 1 end),
            i.name, t.sort_order;
end $$;

revoke all on function waste_report(uuid) from public, anon;
grant execute on function waste_report(uuid) to authenticated;
