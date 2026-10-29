-- Fore canonical install module: 04_reconciliation_reports.sql
-- Run modules in numeric order after database/dev/reset_schema.sql on a test project.

-- >>> Integrated source: database/004_reconcile.sql
-- =====================================================================
-- Fore · 004_reconcile.sql · Hàm đối soát (trái tim của Fore)
--   Thực dùng   = Tồn đầu + Nhập − Tồn cuối
--   Lý thuyết   = Σ (số bán × định lượng công thức)      (lấy từ sổ kho lúc bán)
--   Chênh lệch  = Thực dùng − Lý thuyết
--   Sau điều chỉnh = Chênh lệch − Hao hụt có lý do
--   Quy ra ly   = Chênh lệch điều chỉnh ÷ (lượng trung bình mỗi ly có nguyên liệu đó)
--   Quy ra tiền = số ly × giá bán trung bình (ƯỚC TÍNH)
-- Chỉ chủ quán gọi được. Chạy SAU 003_actions.sql.
-- Ngưỡng cảnh báo là CON SỐ trong app_settings (important_warn_pct, important_alert_pct, normal_warn_pct,
-- normal_alert_pct); mỗi nguyên liệu có thể đặt ngưỡng riêng (ingredients.warn_pct / alert_pct) thì ưu tiên.
-- Giá trị mặc định (TẠM, phải chỉnh theo quán thật): quan trọng 3% / 5%, thường 10% / 15%.
-- Giảm báo nhầm: nguyên liệu có min_abs_qty > 0 chỉ bị cảnh báo khi lệch TUYỆT ĐỐI >= min_abs_qty
-- (đơn vị gốc của nguyên liệu) VÀ lệch % vượt ngưỡng. Mặc định 0 = tắt.
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
declare v_shop uuid;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.id, s.opened_at from shifts s where s.id = p_shift),
  prev as (
    select s.id from shifts s, sh
     where s.shop_id = v_shop and s.status = 'closed' and s.closed_at <= sh.opened_at
     order by s.closed_at desc limit 1
  ),
  ing as (select i.* from ingredients i where i.active and i.shop_id = v_shop),
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
           i.min_abs_qty as min_abs,
           coalesce(i.warn_pct,  _setting(i.importance || '_warn_pct',  case i.importance when 'important' then 3 else 10 end, v_shop)) as warn_at,
           coalesce(i.alert_pct, _setting(i.importance || '_alert_pct', case i.importance when 'important' then 5 else 15 end, v_shop)) as alert_at
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
           when abs(c.adj) < c.min_abs then 'ok'                      -- lệch quá nhỏ về số lượng: bỏ qua (min_abs_qty)
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


-- >>> Integrated source: database/005_cash_reconcile.sql
-- =====================================================================
-- Fore · 005_cash_reconcile.sql · Đối soát TIỀN MẶT
--
--   Tiền mặt đáng ra có = tiền đầu ca
--                         + tiền mặt từ bill đã thanh toán (không tính chuyển khoản, không tính bill đã hủy)
--                         + tiền bỏ thêm vào két (hướng 'in': đổi tiền lẻ, chủ nạp...)
--                         − tiền lấy ra khỏi két (hướng 'out': chi mua đá, trả tiền hàng, chủ rút...)
--   Chênh lệch tiền      = tiền đếm cuối ca − tiền đáng ra có   (âm = THIẾU, dương = THỪA)
--
-- Nguyên tắc thiết kế (đã bàn với chủ dự án):
--   * Chỉ có 2 HƯỚNG (in/out): công thức chỉ cần biết cộng hay trừ. Chi tiết (mua đá, chủ rút...) nằm
--     trong GHI CHÚ do người nhập viết. Không cần PIN, nhưng MỌI khoản đều để lại dấu vết (ai nhập,
--     lúc nào, ghi chú) và không sửa/xóa được. Chủ đọc danh sách ghi chú để biết từng khoản.
--   * Hệ thống KHÔNG kiểm chứng được sự thật bên ngoài (đá thật tốn bao nhiêu, tiền chuyển khoản
--     có về tài khoản không). Đó là giới hạn đã biết: hệ thống chỉ hiện số để chủ so với
--     sao kê ngân hàng/loa báo tiền.
--   * Bán KHÔNG lên bill thì tiền không vào két nên không làm lệch két. Phần đó do đối soát
--     nguyên liệu (reconcile_shift) phát hiện. Hai đối soát đọc cùng nhau mới thấy "kiểu" thất thoát.
--
-- Chạy SAU 004_reconcile.sql.
-- =====================================================================

-- (Các ngưỡng tiền mặt cash_warn_vnd, cash_alert_vnd, opening_diff_warn_vnd nằm trong app_settings, tạo ở 001.)

-- ---------- Thu/chi tiền mặt trong ca ----------
-- Số tiền LUÔN DƯƠNG; cột direction quyết định cộng hay trừ (tránh nhầm dấu khi tính công thức).
--   out = lấy ra khỏi két (−): mua đá, trả tiền hàng, chủ rút...  -> BẮT BUỘC ghi chú (từ 3 ký tự)
--   in  = bỏ thêm vào két (+): đổi tiền lẻ, chủ nạp...             -> ghi chú không bắt buộc
create table cash_movements (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null default app_shop_id() references shops(id),
  shift_id    uuid not null references shifts(id),
  direction   text not null check (direction in ('in', 'out')),
  amount      integer not null check (amount > 0),
  note        text,
  entered_by  uuid not null references staff(id),
  entered_at  timestamptz not null default now(),
  constraint note_required_when_taking_out
    check (direction = 'in' or char_length(btrim(coalesce(note, ''))) >= 3),
  constraint cash_movements_shift_same_shop_fk
    foreign key (shop_id, shift_id) references shifts (shop_id, id),
  constraint cash_movements_entered_by_same_shop_fk
    foreign key (shop_id, entered_by) references staff (shop_id, id)
);
create index cash_movements_shift on cash_movements (shift_id);
create trigger no_change_cash_movements before update or delete on cash_movements
  for each row execute function prevent_mutation();                    -- chỉ thêm, không sửa/xóa
alter table cash_movements enable row level security;
grant select on cash_movements to authenticated;
create policy cash_movements_owner_read on cash_movements for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Nhân viên hoặc chủ đều ghi được (không cần PIN). Chỉ ghi vào ca đang mở.
-- Việc ghi không bắt buộc (ca không có thu/chi thì không có dòng nào).
create or replace function add_cash_movement(p_direction text, p_amount integer, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if p_direction is null or p_direction not in ('in', 'out') then raise exception 'DIRECTION_INVALID'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'AMOUNT_INVALID'; end if;
  if p_direction = 'out' and char_length(btrim(coalesce(p_note, ''))) < 3 then
    raise exception 'NOTE_REQUIRED';        -- lấy tiền ra thì phải ghi chú
  end if;
  insert into cash_movements (shift_id, direction, amount, note, entered_by)
  values (v_shift, p_direction, p_amount, nullif(btrim(p_note), ''), v_me) returning id into v_id;
  perform _audit('add_cash_movement', 'cash_movements', v_id,
                 jsonb_build_object('direction', p_direction, 'amount', p_amount, 'note', nullif(btrim(p_note), '')));
  return v_id;
end $$;

-- Danh sách các khoản thu/chi (chỉ chủ đọc được vì bảng gốc chặn bằng RLS), kèm tên người nhập.
create or replace view v_cash_movements with (security_invoker = true) as
select m.shift_id, m.entered_at, m.direction, m.amount, m.note, s.full_name as entered_by_name
  from cash_movements m
  join staff s on s.id = m.entered_by;

-- ---------- Hàm đối soát tiền mặt (chỉ chủ) ----------
create or replace function reconcile_cash(p_shift uuid)
returns table (
  shift_id                    uuid,
  opened_at                   timestamptz,
  closed_at                   timestamptz,
  opening_cash                integer,
  prev_closing_cash           integer,      -- tiền cuối ca trước (null nếu là ca đầu tiên)
  opening_diff                integer,      -- tiền đầu ca − tiền cuối ca trước (khác 0 = đáng chú ý)
  cash_sales                  integer,
  transfer_sales              integer,      -- để chủ so với loa/app ngân hàng
  cash_in                     integer,
  cash_out                    integer,
  expected_cash               integer,
  closing_cash                integer,
  variance                    integer,      -- đếm − đáng ra có (âm = thiếu)
  variance_pct                numeric,      -- so với doanh thu tiền mặt
  cancelled_after_paid_count  integer,      -- bill đã thu rồi hủy trong ca (chủ nên xem)
  cancelled_after_paid_amount integer,
  status                      text          -- ok | warn | alert | no_data
)
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.* from shifts s where s.id = p_shift),
  prev as (   -- ca đã đóng gần nhất trước ca này
    select p.closing_cash
      from shifts p, sh
     where p.shop_id = v_shop and p.status = 'closed' and p.closed_at < sh.opened_at and p.closing_cash is not null
     order by p.closed_at desc limit 1
  ),
  sales as (
    select coalesce(sum(b.total_amount) filter (where b.status = 'paid' and b.payment_method = 'cash'), 0)     as cash,
           coalesce(sum(b.total_amount) filter (where b.status = 'paid' and b.payment_method = 'transfer'), 0) as transfer,
           count(*)  filter (where b.status = 'cancelled' and b.paid_at is not null)                           as canc_n,
           coalesce(sum(b.total_amount) filter (where b.status = 'cancelled' and b.paid_at is not null), 0)    as canc_amt
      from bills b where b.shift_id = p_shift
  ),
  mv as (
    select coalesce(sum(m.amount) filter (where m.direction = 'in'),  0) as cin,
           coalesce(sum(m.amount) filter (where m.direction = 'out'), 0) as cout
      from cash_movements m where m.shift_id = p_shift
  ),
  base as (
    select sh.id, sh.opened_at, sh.closed_at, sh.opening_cash, sh.closing_cash,
           (select pr.closing_cash from prev pr) as prev_close,
           sales.cash, sales.transfer, sales.canc_n, sales.canc_amt,
           mv.cin, mv.cout,
           sh.opening_cash + sales.cash + mv.cin - mv.cout as expected,
           _setting('cash_warn_vnd',  20000, v_shop) as warn_at,
           _setting('cash_alert_vnd', 50000, v_shop) as alert_at
      from sh, sales, mv
  )
  select b.id, b.opened_at, b.closed_at, b.opening_cash,
         b.prev_close,
         (b.opening_cash - b.prev_close)::integer,
         b.cash::integer, b.transfer::integer, b.cin::integer, b.cout::integer,
         b.expected::integer, b.closing_cash,
         (b.closing_cash - b.expected)::integer,
         round((b.closing_cash - b.expected) * 100.0 / nullif(b.cash, 0), 1),
         b.canc_n::integer, b.canc_amt::integer,
         case when b.closing_cash is null then 'no_data'
              when abs(b.closing_cash - b.expected) >= b.alert_at then 'alert'
              when abs(b.closing_cash - b.expected) >= b.warn_at  then 'warn'
              else 'ok' end
    from base b;
end $$;

-- ---------- Quyền chạy hàm ----------
revoke all on function add_cash_movement(text, integer, text), reconcile_cash(uuid) from public, anon;
grant execute on function add_cash_movement(text, integer, text), reconcile_cash(uuid) to authenticated;
grant select on v_cash_movements to authenticated;


-- >>> Integrated source: database/006_waste_report.sql
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


-- >>> Integrated source: database/007_corrections.sql
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


-- >>> Integrated source: database/009_shift_report.sql
-- =====================================================================
-- Fore · 009_shift_report.sql · MỘT hàm báo cáo cho màn hình chủ
--
-- shift_report(ca) gom mọi thứ chủ cần xem về một ca vào MỘT khối JSON:
--   summary         trạng thái chung (ok | warn | alert | no_data) và số lượng từng loại cảnh báo
--   ingredients     kết quả reconcile_shift (004) + cờ XU HƯỚNG (streak_count, streak_flag)
--   cash            kết quả reconcile_cash (005)
--   waste           kết quả waste_report (006)
--   cash_movements  các khoản thu/chi tiền mặt trong ca (ghi chú, người nhập, giờ)
--   warnings        nhắc việc (ví dụ số món chưa có công thức)
-- App chỉ cần gọi MỘT lần: supabase.rpc('shift_report', params: {'p_shift': id}).
--
-- Cờ XU HƯỚNG (giảm báo nhầm): một ca lệch nhẹ chưa chắc là gian lận, nhưng nhiều ca LIÊN TIẾP
-- lệch CÙNG CHIỀU (cùng dương hoặc cùng âm) thì đáng nghi hơn nhiều. streak_count là số ca liên
-- tiếp (tính đến ca đang xem) mà nguyên liệu đó bị vàng/đỏ cùng chiều; streak_flag = true khi
-- streak_count >= streak_shifts (con số trong app_settings, mặc định 3, tối thiểu 2).
--
-- Chỉ CẢNH BÁO, không chặn; chủ tự quyết định. Chỉ chủ gọi được.
-- Chạy SAU 008_staff_setup.sql.
-- =====================================================================

create or replace function shift_report(p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_n           int;
  v_shop        uuid;
  v_opened      timestamptz;
  v_map         jsonb := '{}'::jsonb;      -- mã nguyên liệu -> {"n": số ca liên tiếp, "sign": chiều lệch, "alive": còn đang nối}
  v_seen        text[];
  v_key         text;
  v_prev        uuid;
  r             record;
  r2            record;
  e             jsonb;
  v_cur         jsonb;                     -- kết quả đối soát của ca đang xem (tính 1 lần, dùng lại)
  v_ingredients jsonb := '[]'::jsonb;
  v_cash        jsonb;
  v_waste       jsonb;
  v_moves       jsonb;
  v_missing     integer;
  v_streak      integer;
  v_rank        integer := 0;              -- 0 ok, 1 warn, 2 alert
  v_has_data    boolean := false;
  n_alert       integer := 0;
  n_warn        integer := 0;
  n_streak      integer := 0;
  n_waste_warn  integer := 0;
  v_cash_status text;
  v_overall     text;
  v_shift       jsonb;
begin
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;
  select opened_at into v_opened from shifts where id = p_shift;
  if v_opened is null then raise exception 'NOT_FOUND'; end if;
  v_n := greatest(_setting('streak_shifts', 3, v_shop), 2);

  -- reconcile_shift là hàm nặng nhất: gọi đúng 1 lần cho ca đang xem rồi giữ kết quả trong v_cur
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_cur from reconcile_shift(p_shift) x;

  -- (1) Chuỗi lệch cùng chiều: bắt đầu từ ca đang xem
  for e in select value from jsonb_array_elements(v_cur) loop
    if e ->> 'status' in ('warn', 'alert') and coalesce((e ->> 'adjusted_variance')::numeric, 0) <> 0 then
      v_map := v_map || jsonb_build_object(e ->> 'ingredient_id',
                 jsonb_build_object('n', 1, 'sign', sign((e ->> 'adjusted_variance')::numeric), 'alive', true));
    end if;
  end loop;

  -- (2) Lùi về các ca đã đóng trước đó (tối đa streak_shifts - 1 ca), nối chuỗi nếu vẫn lệch cùng chiều
  for v_prev in
    select id from shifts where shop_id = v_shop and status = 'closed' and opened_at < v_opened
     order by opened_at desc limit v_n - 1
  loop
    v_seen := '{}';
    for r2 in select * from reconcile_shift(v_prev) loop
      v_key := r2.ingredient_id::text;
      if v_map ? v_key and (v_map -> v_key ->> 'alive')::boolean then
        v_seen := v_seen || v_key;
        if r2.status in ('warn', 'alert') and coalesce(r2.adjusted_variance, 0) <> 0
           and sign(r2.adjusted_variance) = (v_map -> v_key ->> 'sign')::int then
          v_map := jsonb_set(v_map, array[v_key, 'n'], to_jsonb((v_map -> v_key ->> 'n')::int + 1));
        else
          v_map := jsonb_set(v_map, array[v_key, 'alive'], 'false'::jsonb);
        end if;
      end if;
    end loop;
    -- nguyên liệu không có dòng nào ở ca trước: chuỗi đứt
    for v_key in select k from jsonb_object_keys(v_map) k loop
      if (v_map -> v_key ->> 'alive')::boolean and not (v_key = any (v_seen)) then
        v_map := jsonb_set(v_map, array[v_key, 'alive'], 'false'::jsonb);
      end if;
    end loop;
  end loop;

  -- (3) Danh sách nguyên liệu kèm cờ xu hướng, và đếm cảnh báo
  for e in select value from jsonb_array_elements(v_cur) loop
    v_streak := coalesce((v_map -> (e ->> 'ingredient_id') ->> 'n')::int, 0);
    v_ingredients := v_ingredients || (e || jsonb_build_object(
                       'streak_count', v_streak, 'streak_flag', v_streak >= v_n));
    if e ->> 'status' <> 'no_data' then v_has_data := true; end if;
    if e ->> 'status' = 'alert' then n_alert := n_alert + 1; v_rank := greatest(v_rank, 2);
    elsif e ->> 'status' = 'warn' then n_warn := n_warn + 1; v_rank := greatest(v_rank, 1);
    end if;
    if v_streak >= v_n then n_streak := n_streak + 1; v_rank := greatest(v_rank, 1); end if;
  end loop;

  -- (4) Tiền mặt
  select to_jsonb(c), c.status into v_cash, v_cash_status from reconcile_cash(p_shift) c;
  if v_cash_status is not null and v_cash_status <> 'no_data' then
    v_has_data := true;
    if v_cash_status = 'alert' then v_rank := greatest(v_rank, 2);
    elsif v_cash_status = 'warn' then v_rank := greatest(v_rank, 1); end if;
  end if;

  -- (5) Hao hụt
  select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb), count(*) filter (where w.flag = 'warn')
    into v_waste, n_waste_warn from waste_report(p_shift) w;
  if n_waste_warn > 0 then v_rank := greatest(v_rank, 1); end if;

  -- (6) Các khoản thu/chi và nhắc việc
  select coalesce(jsonb_agg(to_jsonb(m) order by m.entered_at), '[]'::jsonb) into v_moves
    from v_cash_movements m where m.shift_id = p_shift;
  select count(*) into v_missing
    from menu_sizes ms join menu_items mi on mi.id = ms.item_id
   where ms.shop_id = v_shop and ms.active and mi.active
     and not exists (select 1 from recipe_lines rl where rl.size_id = ms.id);

  v_overall := case when not v_has_data then 'no_data'
                    when v_rank >= 2 then 'alert'
                    when v_rank = 1 then 'warn'
                    else 'ok' end;

  select jsonb_build_object('id', s.id, 'opened_at', s.opened_at, 'closed_at', s.closed_at, 'status', s.status)
    into v_shift from shifts s where s.id = p_shift;

  return jsonb_build_object(
    'shift', v_shift,
    'summary', jsonb_build_object(
      'overall', v_overall,
      'ingredient_alerts', n_alert, 'ingredient_warns', n_warn,
      'streak_flags', n_streak,
      'cash_status', coalesce(v_cash_status, 'no_data'),
      'waste_warns', n_waste_warn,
      'streak_shifts_setting', v_n),
    'ingredients', v_ingredients,
    'cash', coalesce(v_cash, '{}'::jsonb),
    'waste', v_waste,
    'cash_movements', v_moves,
    'warnings', jsonb_build_object('items_without_recipe', v_missing));
end $$;

revoke all on function shift_report(uuid) from public, anon;
grant execute on function shift_report(uuid) to authenticated;
