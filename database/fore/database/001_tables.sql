-- =====================================================================
-- Fore · 001_tables.sql · Các bảng và ràng buộc
-- Chạy trên Supabase (PostgreSQL 15+). Chạy file này TRƯỚC.
-- Quy ước: id = UUID không mã hóa ý nghĩa; tiền = số nguyên (đồng);
--          định lượng = số nguyên theo đơn vị gốc (ml, g, piece).
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------- Nhân sự ----------
create table staff (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique,                       -- liên kết tài khoản đăng nhập Supabase Auth
  full_name     text not null,
  role          text not null check (role in ('owner','staff')),
  pin_hash      text,                              -- PIN đã băm (bcrypt), không bao giờ lưu PIN thô
  active        boolean not null default true,     -- không xóa, chỉ ẩn
  created_at    timestamptz not null default now()
);

-- ---------- Nguyên liệu, món, công thức ----------
create table ingredients (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  group_name   text,                               -- nhóm (topping, sữa, trà...) tách riêng khỏi id
  unit         text not null check (unit in ('ml','g','piece')),
  importance   text not null default 'normal' check (importance in ('important','normal')),
  weekly_check boolean not null default false,     -- chỉ cần kiểm theo tuần (đường, muối...)
  warn_pct     numeric(5,2) check (warn_pct  >= 0), -- ngưỡng riêng (để trống = dùng mặc định theo importance)
  alert_pct    numeric(5,2) check (alert_pct >= 0),
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  check (warn_pct is null or alert_pct is null or warn_pct <= alert_pct)
);
-- Chống trùng tên gần giống nhau (không phân biệt hoa thường, bỏ khoảng trắng thừa)
create unique index ingredients_name_uq on ingredients (lower(btrim(name)));

create table menu_items (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  group_name  text,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create unique index menu_items_name_uq on menu_items (lower(btrim(name)));

-- Mỗi size có giá riêng và công thức riêng
create table menu_sizes (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references menu_items(id),
  size_name   text not null,
  price       integer not null check (price >= 0),  -- đồng
  active      boolean not null default true,
  unique (item_id, size_name)
);

create table recipe_lines (
  id             uuid primary key default gen_random_uuid(),
  size_id        uuid not null references menu_sizes(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),  -- theo đơn vị gốc của nguyên liệu
  unique (size_id, ingredient_id)
);

-- ---------- Khu vực và bàn (do người dùng tự tạo) ----------
create table areas (
  id      uuid primary key default gen_random_uuid(),
  name    text not null unique,
  active  boolean not null default true
);

create table dining_tables (
  id       uuid primary key default gen_random_uuid(),
  area_id  uuid not null references areas(id),
  name     text not null,
  active   boolean not null default true,
  unique (area_id, name)
);

-- ---------- Ca làm việc ----------
create table shifts (
  id            uuid primary key default gen_random_uuid(),
  opened_by     uuid not null references staff(id),
  opened_at     timestamptz not null default now(),   -- giờ máy chủ, không lấy giờ điện thoại
  closed_by     uuid references staff(id),
  closed_at     timestamptz,
  opening_cash  integer not null default 0 check (opening_cash >= 0),
  closing_cash  integer check (closing_cash >= 0),
  status        text not null default 'open' check (status in ('open','closed'))
);
-- Tại một thời điểm chỉ có tối đa 1 ca đang mở
create unique index one_open_shift on shifts ((1)) where status = 'open';

-- ---------- Hóa đơn ----------
create table bills (
  id               uuid primary key default gen_random_uuid(),
  bill_no          bigint generated always as identity,  -- số bill tuần tự, không bị nhảy tay
  shift_id         uuid not null references shifts(id),
  table_id         uuid references dining_tables(id),
  bill_type        text not null check (bill_type in ('dine_in','take_away')),
  guests           integer check (guests > 0),
  status           text not null default 'open' check (status in ('open','paid','cancelled')),
  opened_by        uuid not null references staff(id),
  opened_at        timestamptz not null default now(),
  paid_by          uuid references staff(id),
  paid_at          timestamptz,
  payment_method   text check (payment_method in ('cash','transfer')),
  discount         integer not null default 0 check (discount >= 0),
  discount_reason  text,
  total_amount     integer check (total_amount >= 0),     -- chốt lúc thanh toán
  cancelled_by     uuid references staff(id),
  cancelled_at     timestamptz,
  cancel_reason    text,
  approved_by      uuid references staff(id),             -- chủ xác nhận bằng PIN khi hủy bill đã thu tiền
  prep_done_at     timestamptz,                           -- đơn mang đi: đã làm xong chưa
  check (bill_type <> 'dine_in' or table_id is not null),
  check (status <> 'cancelled' or cancel_reason is not null)
);
create unique index bills_bill_no_uq on bills (bill_no);
-- CHỐNG 2 MÁY CÙNG MỞ/THANH TOÁN 1 BÀN: mỗi bàn chỉ có tối đa 1 bill đang mở
create unique index one_open_bill_per_table on bills (table_id)
  where status = 'open' and table_id is not null;
create index bills_shift_idx on bills (shift_id);

create table bill_lines (
  id           uuid primary key default gen_random_uuid(),
  bill_id      uuid not null references bills(id),
  size_id      uuid not null references menu_sizes(id),
  qty          integer not null check (qty > 0),
  unit_price   integer not null check (unit_price >= 0),  -- giá tại thời điểm bán (không tính lại)
  created_at   timestamptz not null default now(),
  created_by   uuid references staff(id),
  voided_at    timestamptz,                               -- không xóa dòng, chỉ đánh dấu hủy
  voided_by    uuid references staff(id),
  void_reason  text,
  check (voided_at is null or void_reason is not null)
);
create index bill_lines_bill_idx on bill_lines (bill_id);

-- ---------- Kho: nhập, đếm, hao hụt, sổ kho ----------
create table purchases (
  id             uuid primary key default gen_random_uuid(),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),
  is_late_entry  boolean not null default false,          -- "nhập bù" (viết giấy rồi nhập lại)
  note           text,
  entered_by     uuid references staff(id),
  entered_at     timestamptz not null default now()
);

create table stock_counts (                               -- kiểm kê (đếm mù)
  id             uuid primary key default gen_random_uuid(),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  kind           text not null check (kind in ('open','close')),
  counted_qty    integer not null check (counted_qty >= 0),
  counted_by     uuid references staff(id),
  counted_at     timestamptz not null default now()
);
create index stock_counts_lookup on stock_counts (shift_id, ingredient_id, kind, counted_at desc);

create table waste_logs (                                 -- hao hụt có lý do (đổ, làm sai, thử vị...)
  id             uuid primary key default gen_random_uuid(),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),
  reason         text not null,
  entered_by     uuid references staff(id),
  entered_at     timestamptz not null default now()
);

-- SỔ KHO: mỗi lần nhập, bán, hao hụt là 1 dòng. Tồn kho = tổng các dòng.
create table stock_ledger (
  id             bigint generated always as identity primary key,
  at             timestamptz not null default now(),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  kind           text not null check (kind in ('purchase','sale','void_sale','waste')),
  qty_delta      integer not null check (qty_delta <> 0), -- nhập: +; bán/hao hụt: -; hủy bill: +
  ref_id         uuid,                                    -- bill_id hoặc id phiếu nhập/hao hụt
  created_by     uuid references staff(id)
);
create index stock_ledger_ing_at on stock_ledger (ingredient_id, at);
create index stock_ledger_shift on stock_ledger (shift_id, kind);

-- ---------- Nhật ký và PIN ----------
create table audit_log (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  actor      uuid,
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  detail     jsonb
);

create table pin_attempts (
  id        bigint generated always as identity primary key,
  at        timestamptz not null default now(),
  staff_id  uuid not null references staff(id),
  ok        boolean not null
);
create index pin_attempts_lookup on pin_attempts (staff_id, at desc);
