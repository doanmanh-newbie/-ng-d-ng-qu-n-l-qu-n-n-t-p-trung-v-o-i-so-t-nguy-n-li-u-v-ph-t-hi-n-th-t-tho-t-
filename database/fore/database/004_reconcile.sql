-- =====================================================================
-- Fore · 004_reconcile.sql · Hàm đối soát (trái tim của Fore)
--   Thực dùng   = Tồn đầu + Nhập − Tồn cuối
--   Lý thuyết   = Σ (số bán × định lượng công thức)      (lấy từ sổ kho lúc bán)
--   Chênh lệch  = Thực dùng − Lý thuyết
--   Sau điều chỉnh = Chênh lệch − Hao hụt có lý do
--   Quy ra ly   = Chênh lệch điều chỉnh ÷ (lượng trung bình mỗi ly có nguyên liệu đó)
--   Quy ra tiền = số ly × giá bán trung bình (ƯỚC TÍNH)
-- Chỉ chủ quán gọi được. Chạy SAU 003_actions.sql.
-- Ngưỡng mặc định (TẠM, cần chỉnh theo quán thật):
--   nguyên liệu 'important': cảnh báo vàng >= 3%, đỏ >= 5%
--   nguyên liệu 'normal'   : cảnh báo vàng >= 10%, đỏ >= 15%
-- =====================================================================

create or replace function reconcile_shift(p_shift uuid)
returns table (
  ingredient_id     uuid,
  ingredient_name   text,
  unit              text,
  importance        text,
  opening_qty       integer,
  purchased_qty     integer,
  closing_qty       integer,
  actual_used       integer,
  theoretical_used  integer,
  variance          integer,
  variance_pct      numeric,
  justified_waste   integer,
  adjusted_variance integer,
  adjusted_pct      numeric,
  equiv_cups        numeric,
  equiv_revenue     integer,
  status            text          -- ok | warn | alert | no_data
)
language plpgsql stable security definer set search_path = public as $$
begin
  -- Chỉ chủ (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  if not (app_is_owner() or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.id, s.opened_at from shifts s where s.id = p_shift),
  prev as (
    select s.id from shifts s, sh
     where s.status = 'closed' and s.closed_at <= sh.opened_at
     order by s.closed_at desc limit 1
  ),
  ing as (select i.* from ingredients i where i.active),
  op as (   -- tồn đầu: lần đếm 'open' của ca này, nếu không có thì lấy đếm cuối ca trước
    select i.id as iid,
           coalesce(
             (select c.counted_qty from stock_counts c
               where c.shift_id = p_shift and c.ingredient_id = i.id and c.kind = 'open'
               order by c.counted_at desc limit 1),
             (select c.counted_qty from stock_counts c
               where c.shift_id = (select id from prev) and c.ingredient_id = i.id and c.kind = 'close'
               order by c.counted_at desc limit 1)) as q
      from ing i
  ),
  cl as (
    select i.id as iid,
           (select c.counted_qty from stock_counts c
             where c.shift_id = p_shift and c.ingredient_id = i.id and c.kind = 'close'
             order by c.counted_at desc limit 1) as q
      from ing i
  ),
  pu as (select l.ingredient_id as iid, sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind = 'purchase' group by 1),
  th as (select l.ingredient_id as iid, -sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind in ('sale','void_sale') group by 1),
  wa as (select l.ingredient_id as iid, -sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind = 'waste' group by 1),
  cups as (  -- số ly có chứa nguyên liệu và doanh thu của chúng (để quy ra ly/tiền)
    select r.ingredient_id as iid, sum(bl.qty) as cups, sum(bl.qty::bigint * bl.unit_price) as revenue
      from bill_lines bl
      join bills b on b.id = bl.bill_id and b.status = 'paid' and b.shift_id = p_shift
      join recipe_lines r on r.size_id = bl.size_id
     where bl.voided_at is null
     group by r.ingredient_id
  ),
  base as (
    select i.id, i.name, i.unit, i.importance,
           op.q as opening, coalesce(pu.q, 0) as purchased, cl.q as closing,
           coalesce(th.q, 0) as theo, coalesce(wa.q, 0) as waste,
           cups.cups, cups.revenue,
           coalesce(i.warn_pct,  case i.importance when 'important' then 3  else 10 end) as warn_at,
           coalesce(i.alert_pct, case i.importance when 'important' then 5  else 15 end) as alert_at
      from ing i
      join op on op.iid = i.id
      join cl on cl.iid = i.id
      left join pu on pu.iid = i.id
      left join th on th.iid = i.id
      left join wa on wa.iid = i.id
      left join cups on cups.iid = i.id
     where not i.weekly_check or cl.q is not null    -- loại kiểm theo tuần: chỉ hiện khi có đếm
  ),
  calc as (
    select b.*,
           case when b.opening is not null and b.closing is not null
                then b.opening + b.purchased - b.closing end as actual
      from base b
  ),
  calc2 as (
    select c.*,
           c.actual - c.theo as var,
           c.actual - c.theo - c.waste as adj
      from calc c
  )
  select c.id, c.name, c.unit, c.importance,
         c.opening::integer, c.purchased::integer, c.closing::integer,
         c.actual::integer, c.theo::integer,
         c.var::integer,
         round(c.var * 100.0 / nullif(c.theo, 0), 1),
         c.waste::integer,
         c.adj::integer,
         round(c.adj * 100.0 / nullif(c.theo, 0), 1),
         round(c.adj / nullif(c.theo::numeric / nullif(c.cups, 0), 0), 1),
         round(c.adj / nullif(c.theo::numeric / nullif(c.cups, 0), 0) * (c.revenue::numeric / nullif(c.cups, 0)))::integer,
         case
           when c.actual is null then 'no_data'
           when c.theo = 0 then case when c.adj <= 0 then 'ok' else 'warn' end   -- không bán gì mà vẫn hao
           when abs(c.adj * 100.0 / c.theo) >= c.alert_at then 'alert'
           when abs(c.adj * 100.0 / c.theo) >= c.warn_at  then 'warn'
           else 'ok'
         end
    from calc2 c
   order by (c.importance = 'important') desc, abs(coalesce(c.adj, 0)) desc;
end $$;

revoke all on function reconcile_shift(uuid) from public, anon, authenticated;
grant execute on function reconcile_shift(uuid) to authenticated;

-- ---------- Tồn dự kiến và "còn pha được" (CHỈ CHỦ xem được nhờ RLS) ----------
create or replace view v_expected_stock with (security_invoker = true) as
select i.id as ingredient_id, i.name, i.unit,
       c.counted_qty + coalesce((select sum(l.qty_delta) from stock_ledger l
                                  where l.ingredient_id = i.id and l.at > c.counted_at), 0) as expected_qty,
       c.counted_at as last_count_at
  from ingredients i
  left join lateral (select counted_qty, counted_at from stock_counts
                      where ingredient_id = i.id order by counted_at desc limit 1) c on true
 where i.active;

create or replace view v_can_make with (security_invoker = true) as
select ms.id as size_id, mi.name as item_name, ms.size_name,
       min(floor(e.expected_qty::numeric / r.qty))::integer as cups_left
  from menu_sizes ms
  join menu_items mi on mi.id = ms.item_id
  join recipe_lines r on r.size_id = ms.id
  join v_expected_stock e on e.ingredient_id = r.ingredient_id
 where ms.active and mi.active and e.expected_qty is not null
 group by ms.id, mi.name, ms.size_name;

grant select on v_expected_stock, v_can_make to authenticated;

-- Món đã bán nhưng chưa có công thức (sẽ làm đối soát bị thiếu): nhắc chủ quán
create or replace view v_items_without_recipe with (security_invoker = true) as
select ms.id as size_id, mi.name as item_name, ms.size_name
  from menu_sizes ms join menu_items mi on mi.id = ms.item_id
 where ms.active and mi.active
   and not exists (select 1 from recipe_lines r where r.size_id = ms.id);
grant select on v_items_without_recipe to authenticated;
