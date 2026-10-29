-- =====================================================================
-- Fore · 007_corrections.sql · Sửa nhập nhầm bằng dòng ĐIỀU CHỈNH (không sửa dòng cũ)
--   - Nhập kho hoặc hao hụt sai số: chủ ghi thêm một dòng điều chỉnh có lý do, dòng gốc vẫn còn.
--   - Kiểm kê sai: nhân viên đếm lại (dòng mới nhất được dùng), không cần điều chỉnh.
--   - Hàm đối soát (004) tự cộng các dòng điều chỉnh vì chúng nằm trong sổ kho.
-- Chạy SAU 006_waste_report.sql.
-- =====================================================================

alter table stock_ledger
  add column is_correction boolean not null default false,
  add column note text;

-- Sửa số lượng của một phiếu nhập: chỉ chủ
create or replace function correct_purchase(p_purchase uuid, p_new_qty integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_shift uuid; v_ing uuid; v_cur integer; v_delta integer;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  if p_new_qty < 0 then raise exception 'QTY_INVALID'; end if;
  select shift_id, ingredient_id into v_shift, v_ing from purchases where id = p_purchase and shop_id = app_shop_id();
  if v_shift is null then raise exception 'NOT_FOUND'; end if;

  select coalesce(sum(qty_delta), 0) into v_cur from stock_ledger where kind = 'purchase' and ref_id = p_purchase;
  v_delta := p_new_qty - v_cur;
  if v_delta = 0 then raise exception 'NO_CHANGE'; end if;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
  values (v_shift, v_ing, 'purchase', v_delta, p_purchase, v_me, true, p_reason);
  perform _audit('correct_purchase', 'purchases', p_purchase,
                 jsonb_build_object('from', v_cur, 'to', p_new_qty, 'reason', p_reason));
end $$;

-- Sửa số lượng của một dòng hao hụt: chỉ chủ
create or replace function correct_waste(p_waste uuid, p_new_qty integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_shift uuid; v_ing uuid; v_cur integer; v_delta integer;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  if p_new_qty < 0 then raise exception 'QTY_INVALID'; end if;
  select shift_id, ingredient_id into v_shift, v_ing from waste_logs where id = p_waste and shop_id = app_shop_id();
  if v_shift is null then raise exception 'NOT_FOUND'; end if;

  select coalesce(-sum(qty_delta), 0) into v_cur from stock_ledger where kind = 'waste' and ref_id = p_waste;
  v_delta := v_cur - p_new_qty;          -- dòng sổ kho của hao hụt mang dấu âm
  if v_delta = 0 then raise exception 'NO_CHANGE'; end if;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
  values (v_shift, v_ing, 'waste', v_delta, p_waste, v_me, true, p_reason);
  perform _audit('correct_waste', 'waste_logs', p_waste,
                 jsonb_build_object('from', v_cur, 'to', p_new_qty, 'reason', p_reason));
end $$;

-- ---------- View báo cáo (chỉ chủ xem được nhờ RLS của bảng gốc) ----------
-- Số lượng nhập thực tế sau điều chỉnh
create or replace view v_purchases_effective with (security_invoker = true) as
select p.id, p.shift_id, p.ingredient_id, p.qty as original_qty,
       coalesce((select sum(l.qty_delta) from stock_ledger l where l.kind = 'purchase' and l.ref_id = p.id), p.qty) as effective_qty,
       (select count(*) from stock_ledger l where l.kind = 'purchase' and l.ref_id = p.id and l.is_correction) as corrections
  from purchases p;

-- Tổng hao hụt theo tuần, nguyên liệu và loại (đã tính điều chỉnh)
create or replace view v_waste_summary with (security_invoker = true) as
select date_trunc('week', w.entered_at)::date as week_start,
       w.ingredient_id, i.name as ingredient_name, w.reason_type,
       count(*) filter (where not l.is_correction) as entries,
       -sum(l.qty_delta) as total_qty
  from waste_logs w
  join stock_ledger l on l.kind = 'waste' and l.ref_id = w.id
  join ingredients i on i.id = w.ingredient_id
 group by 1, 2, 3, 4;

-- Nguyên liệu bị đếm lại nhiều lần trong một ca (đếm lại để "thử cho đẹp số")
create or replace view v_recount_flags with (security_invoker = true) as
select c.shift_id, c.ingredient_id, c.kind, count(*) as times_counted
  from stock_counts c
 group by c.shift_id, c.ingredient_id, c.kind
having count(*) > coalesce((select a.value_int from app_settings a
                              where a.key = 'recount_flag_after'
                                and a.shop_id = app_shop_id()), 2);

grant select on v_purchases_effective, v_waste_summary, v_recount_flags to authenticated;

revoke all on function correct_purchase(uuid, integer, text), correct_waste(uuid, integer, text) from public, anon;
grant execute on function correct_purchase(uuid, integer, text), correct_waste(uuid, integer, text) to authenticated;
