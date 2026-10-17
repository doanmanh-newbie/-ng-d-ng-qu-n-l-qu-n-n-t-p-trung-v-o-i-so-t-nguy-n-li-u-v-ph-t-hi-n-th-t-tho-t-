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
  shift_id    uuid not null references shifts(id),
  direction   text not null check (direction in ('in', 'out')),
  amount      integer not null check (amount > 0),
  note        text,
  entered_by  uuid not null references staff(id),
  entered_at  timestamptz not null default now(),
  constraint note_required_when_taking_out
    check (direction = 'in' or char_length(btrim(coalesce(note, ''))) >= 3)
);
create index cash_movements_shift on cash_movements (shift_id);
create trigger no_change_cash_movements before update or delete on cash_movements
  for each row execute function prevent_mutation();                    -- chỉ thêm, không sửa/xóa
alter table cash_movements enable row level security;
grant select on cash_movements to authenticated;
create policy cash_movements_owner_read on cash_movements for select to authenticated using (app_is_owner());

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
begin
  if not (app_is_owner() or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.* from shifts s where s.id = p_shift),
  prev as (   -- ca đã đóng gần nhất trước ca này
    select p.closing_cash
      from shifts p, sh
     where p.status = 'closed' and p.closed_at < sh.opened_at and p.closing_cash is not null
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
           _setting('cash_warn_vnd',  20000) as warn_at,
           _setting('cash_alert_vnd', 50000) as alert_at
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
