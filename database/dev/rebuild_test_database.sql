-- Fore test reset + full rebuild. DESTRUCTIVE: test database only. Auth users remain; public schema/data will be dropped.
-- Paste this one file into Supabase SQL Editor and run once. Includes 001-015 in dependency order.

-- >>> SOURCE: database/dev/reset_schema.sql
-- NGUY HIỂM: XÓA TOÀN BỘ bảng, view, hàm do Fore tạo trong schema public (để chạy lại 001 từ đầu).
-- CHỈ dùng trên project Supabase THỬ. KHÔNG chạy trên database có dữ liệu thật của quán.
-- Không đụng tới schema auth (tài khoản đăng nhập vẫn còn).
drop schema public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
create extension if not exists pgcrypto with schema extensions;


-- >>> SOURCE: database/001_tables.sql
-- =====================================================================
-- Fore · 001_tables.sql · Các bảng và ràng buộc (NHIỀU QUÁN: mọi dữ liệu nghiệp vụ có shop_id)
-- Chạy trên Supabase (PostgreSQL 15+). Chạy file này TRƯỚC.
-- Quy ước: id = UUID không mã hóa ý nghĩa; tiền = số nguyên (đồng);
--          định lượng = số nguyên theo đơn vị gốc (ml, g, piece).
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------- Quán, nhân sự, lời mời ----------
-- Một người (một tài khoản đăng nhập) có thể thuộc NHIỀU quán: mỗi quán là một dòng trong bảng staff
-- (staff = "tư cách thành viên của quán"; tên hiển thị và vai trò là RIÊNG từng quán).
create table shops (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) >= 1),
  created_by  uuid,                                -- auth.users.id của người tạo quán
  created_at  timestamptz not null default now()
);

create table staff (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id),
  auth_user_id  uuid,                              -- liên kết tài khoản đăng nhập Supabase Auth (null: nhân sự mô phỏng)
  full_name     text not null,                     -- tên hiển thị trong quán này
  birth_date    date,                               -- ngày sinh nhân viên (có thể null với hồ sơ cũ/chủ quán)
  role          text not null check (role in ('owner','staff')),
  pin_hash      text,                              -- PIN đã băm (bcrypt), không bao giờ lưu PIN thô
  active        boolean not null default true,     -- không xóa, chỉ ẩn
  created_at    timestamptz not null default now(),
  unique (shop_id, auth_user_id),
  unique (shop_id, id)
);
create index staff_user_idx on staff (auth_user_id) where active;

-- Quán đang chọn của mỗi người (người thuộc nhiều quán chọn quán nào thì app làm việc với quán đó)
create table user_settings (
  auth_user_id    uuid primary key,
  active_shop_id  uuid references shops(id)
);

-- Lời mời vào quán: chủ nhập SỐ ĐIỆN THOẠI (có thể thêm email) của nhân viên.
-- Người nhận thấy lời mời trong hộp thư của app khi đăng nhập bằng số điện thoại/email ĐÃ XÁC THỰC khớp.
create table shop_invites (
  id                uuid primary key default gen_random_uuid(),
  shop_id           uuid not null references shops(id),
  phone             text not null,                 -- đã chuẩn hóa (chỉ chữ số, đầu số quốc gia): 84901234567
  email             text,                          -- không bắt buộc; viết thường
  full_name         text not null check (char_length(btrim(full_name)) >= 1),
  status            text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  invited_by        uuid not null references staff(id),
  created_at        timestamptz not null default now(),
  responded_at      timestamptz,
  accepted_user_id  uuid
);
create unique index one_pending_invite on shop_invites (shop_id, phone) where status = 'pending';
create index invites_phone_idx on shop_invites (phone) where status = 'pending';

-- ---------- Hàm xác định "tôi là ai, đang ở quán nào" (dùng làm giá trị mặc định shop_id) ----------
create or replace function app_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.shop_id from user_settings u
       join staff s on s.shop_id = u.active_shop_id and s.auth_user_id = u.auth_user_id and s.active
      where u.auth_user_id = auth.uid()),
    (select s.shop_id from staff s where s.auth_user_id = auth.uid() and s.active
      order by s.created_at, s.id limit 1))
$$;

create or replace function app_staff_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from staff where auth_user_id = auth.uid() and active and shop_id = app_shop_id()
$$;

create or replace function app_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff where auth_user_id = auth.uid() and active and role = 'owner'
                    and shop_id = app_shop_id())
$$;

-- ---------- Nguyên liệu, món, công thức ----------
create table ingredients (
  id           uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name         text not null,
  group_name   text,                               -- nhóm (topping, sữa, trà...) tách riêng khỏi id
  unit         text not null check (unit in ('ml','g','piece')),
  importance   text not null default 'normal' check (importance in ('important','normal')),
  weekly_check boolean not null default false,     -- chỉ cần kiểm theo tuần (đường, muối...)
  warn_pct     numeric(5,2) check (warn_pct  >= 0), -- ngưỡng riêng (để trống = dùng mặc định theo importance)
  alert_pct    numeric(5,2) check (alert_pct >= 0),
  min_abs_qty  integer not null default 0 check (min_abs_qty >= 0),  -- lệch tuyệt đối dưới mức này (đơn vị gốc) thì KHÔNG cảnh báo; 0 = tắt
  min_stock_qty integer not null default 0 check (min_stock_qty >= 0), -- ngưỡng tồn thấp; 0 = tắt
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (shop_id, id),
  check (warn_pct is null or alert_pct is null or warn_pct <= alert_pct)
);
-- Chống trùng tên gần giống nhau (không phân biệt hoa thường, bỏ khoảng trắng thừa)
create unique index ingredients_name_uq on ingredients (shop_id, lower(btrim(name)));

create table menu_items (
  id          uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name        text not null,
  group_name  text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (shop_id, id)
);
create unique index menu_items_name_uq on menu_items (shop_id, lower(btrim(name)));

-- Mỗi size có giá riêng và công thức riêng
create table menu_sizes (
  id          uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  item_id     uuid not null references menu_items(id),
  size_name   text not null,
  price       integer not null check (price >= 0),  -- đồng
  active      boolean not null default true,
  unique (item_id, size_name),
  unique (shop_id, id)
);

create table recipe_lines (
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  size_id        uuid not null references menu_sizes(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),  -- theo đơn vị gốc của nguyên liệu
  unique (size_id, ingredient_id)
);

-- ---------- Khu vực và bàn (do người dùng tự tạo) ----------
create table areas (
  id      uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name    text not null,
  active  boolean not null default true,
  unique (shop_id, name),
  unique (shop_id, id)
);

create table dining_tables (
  id       uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  area_id  uuid not null references areas(id),
  name     text not null,
  active   boolean not null default true,
  unique (area_id, name),
  unique (shop_id, id)
);

-- ---------- Ca làm việc ----------
create table shifts (
  id            uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  opened_by     uuid not null references staff(id),
  opened_at     timestamptz not null default now(),   -- giờ máy chủ, không lấy giờ điện thoại
  closed_by     uuid references staff(id),
  closed_at     timestamptz,
  opening_cash  integer not null default 0 check (opening_cash >= 0),
  closing_cash  integer check (closing_cash >= 0),
  status        text not null default 'open' check (status in ('open','closed')),
  constraint shifts_closed_requires_cash
    check (status <> 'closed' or closing_cash is not null),
  unique (shop_id, id)
);
-- Tại một thời điểm, MỖI QUÁN chỉ có tối đa 1 ca đang mở
create unique index one_open_shift on shifts (shop_id) where status = 'open';
create index shifts_shop_time on shifts (shop_id, opened_at desc);   -- danh sách ca, ca trước (đối soát)

-- ---------- Hóa đơn ----------
create table bills (
  id               uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
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
  check (status <> 'cancelled' or cancel_reason is not null),
  constraint paid_bill_requires_payment_details
    check (status <> 'paid' or
           (payment_method is not null and total_amount is not null
            and paid_at is not null and paid_by is not null)),
  unique (shop_id, id)
);
create unique index bills_bill_no_uq on bills (bill_no);
-- CHỐNG 2 MÁY CÙNG MỞ/THANH TOÁN 1 BÀN: mỗi bàn chỉ có tối đa 1 bill đang mở
create unique index one_open_bill_per_table on bills (table_id)
  where status = 'open' and table_id is not null;
create index bills_shift_idx on bills (shift_id);

create table bill_lines (
  id           uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
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
  shop_id uuid not null default app_shop_id() references shops(id),
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
  shop_id uuid not null default app_shop_id() references shops(id),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  kind           text not null check (kind in ('open','close')),
  counted_qty    integer not null check (counted_qty >= 0),
  counted_by     uuid references staff(id),
  counted_at     timestamptz not null default now()
);
create index stock_counts_lookup on stock_counts (shift_id, ingredient_id, kind, counted_at desc);

-- ---------- Cấu hình: công thức nằm trong code, CON SỐ nằm ở đây để chủ quán chỉnh ----------
create table app_settings (
  shop_id     uuid not null default app_shop_id() references shops(id),
  key         text not null,
  value_int   integer not null,
  description text,
  primary key (shop_id, key)
);

-- Loại hao hụt: chỉ là NHÃN nên để thành bảng (chủ thêm/đổi tên/ẩn được, mã code không đổi)
create table waste_types (
  shop_id       uuid not null default app_shop_id() references shops(id),
  code          text not null,
  label_vi      text not null,
  requires_note boolean not null default false,   -- loại này bắt buộc ghi chú (ví dụ "khác")
  active        boolean not null default true,    -- không xóa, chỉ ẩn
  sort_order    integer not null default 0,
  primary key (shop_id, code)
);

-- Mỗi quán mới được tạo sẵn cấu hình và loại hao hụt mặc định (số TẠM, chủ chỉnh theo quán thật)
create or replace function _seed_shop(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into app_settings (shop_id, key, value_int, description) values
    (p_shop, 'important_warn_pct',    3, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo vàng (TẠM, chỉnh theo quán thật)'),
    (p_shop, 'important_alert_pct',   5, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo đỏ'),
    (p_shop, 'normal_warn_pct',      10, 'Nguyên liệu thường: cảnh báo vàng từ mức % này'),
    (p_shop, 'normal_alert_pct',     15, 'Nguyên liệu thường: cảnh báo đỏ từ mức % này'),
    (p_shop, 'waste_warn_pct',       10, 'Hao hụt có lý do vượt mức % này so với lượng dùng lý thuyết thì cảnh báo'),
    (p_shop, 'cash_warn_vnd',     20000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo vàng'),
    (p_shop, 'cash_alert_vnd',    50000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo đỏ'),
    (p_shop, 'opening_diff_warn_vnd', 1000, 'Tiền đầu ca lệch so với tiền cuối ca trước từ mức này (đồng): đáng chú ý'),
    (p_shop, 'recount_flag_after',    2, 'Một nguyên liệu bị đếm lại quá số lần này trong 1 ca thì đưa vào danh sách cần chú ý'),
    (p_shop, 'streak_shifts',         3, 'Số ca LIÊN TIẾP lệch cùng chiều (vàng/đỏ) thì gắn cờ xu hướng trong shift_report (tối thiểu 2)'),
    (p_shop, 'pin_max_attempts',      3, 'Số lần nhập sai PIN chủ liên tiếp thì khóa'),
    (p_shop, 'pin_lock_minutes',     15, 'Số phút khóa PIN sau khi sai quá số lần')
  on conflict do nothing;
  insert into waste_types (shop_id, code, label_vi, requires_note, sort_order) values
    (p_shop, 'expired',    'Đổ bỏ (quá giờ/hết hạn)', false, 1),
    (p_shop, 'mistake',    'Làm sai, đổ ly',          false, 2),
    (p_shop, 'staff_meal', 'Cho nhân viên dùng',       false, 3),
    (p_shop, 'tasting',    'Thử vị',                   false, 4),
    (p_shop, 'other',      'Khác (ghi chú rõ)',        true,  9)
  on conflict do nothing;
end $$;

create or replace function shops_seed_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin perform _seed_shop(new.id); return new; end $$;
create trigger shops_seed after insert on shops for each row execute function shops_seed_trg();

create table waste_logs (                                 -- hao hụt có lý do (đổ, làm sai, thử vị...)
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),
  reason_type    text not null default 'other',                                  -- loại (chọn từ danh sách waste_types của quán)
  reason         text not null,                                                  -- ghi chú (mặc định là tên loại)
  entered_by     uuid references staff(id),
  entered_at     timestamptz not null default now(),
  foreign key (shop_id, reason_type) references waste_types (shop_id, code)
);

-- SỔ KHO: mỗi lần nhập, bán, hao hụt là 1 dòng. Tồn kho = tổng các dòng.
create table stock_ledger (
  id             bigint generated always as identity primary key,
  shop_id uuid not null default app_shop_id() references shops(id),
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
  shop_id uuid not null default app_shop_id() references shops(id),
  at         timestamptz not null default now(),
  actor      uuid,
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  detail     jsonb
);

create table pin_attempts (
  id        bigint generated always as identity primary key,
  shop_id uuid not null default app_shop_id() references shops(id),
  at        timestamptz not null default now(),
  staff_id  uuid not null references staff(id),
  ok        boolean not null
);
create index pin_attempts_lookup on pin_attempts (staff_id, at desc);

-- UUID vẫn là khóa chính toàn cục; các khóa ghép này buộc quan hệ nghiệp vụ
-- luôn trỏ tới bản ghi cùng quán, kể cả khi có lệnh ghi trực tiếp vào bảng.
alter table shop_invites add constraint shop_invites_inviter_same_shop_fk
  foreign key (shop_id, invited_by) references staff (shop_id, id);
alter table menu_sizes add constraint menu_sizes_item_same_shop_fk
  foreign key (shop_id, item_id) references menu_items (shop_id, id);
alter table recipe_lines add constraint recipe_lines_size_same_shop_fk
  foreign key (shop_id, size_id) references menu_sizes (shop_id, id);
alter table recipe_lines add constraint recipe_lines_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table dining_tables add constraint dining_tables_area_same_shop_fk
  foreign key (shop_id, area_id) references areas (shop_id, id);
alter table shifts add constraint shifts_opened_by_same_shop_fk
  foreign key (shop_id, opened_by) references staff (shop_id, id);
alter table shifts add constraint shifts_closed_by_same_shop_fk
  foreign key (shop_id, closed_by) references staff (shop_id, id);
alter table bills add constraint bills_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table bills add constraint bills_table_same_shop_fk
  foreign key (shop_id, table_id) references dining_tables (shop_id, id);
alter table bills add constraint bills_opened_by_same_shop_fk
  foreign key (shop_id, opened_by) references staff (shop_id, id);
alter table bills add constraint bills_paid_by_same_shop_fk
  foreign key (shop_id, paid_by) references staff (shop_id, id);
alter table bills add constraint bills_cancelled_by_same_shop_fk
  foreign key (shop_id, cancelled_by) references staff (shop_id, id);
alter table bills add constraint bills_approved_by_same_shop_fk
  foreign key (shop_id, approved_by) references staff (shop_id, id);
alter table bill_lines add constraint bill_lines_bill_same_shop_fk
  foreign key (shop_id, bill_id) references bills (shop_id, id);
alter table bill_lines add constraint bill_lines_size_same_shop_fk
  foreign key (shop_id, size_id) references menu_sizes (shop_id, id);
alter table bill_lines add constraint bill_lines_created_by_same_shop_fk
  foreign key (shop_id, created_by) references staff (shop_id, id);
alter table bill_lines add constraint bill_lines_voided_by_same_shop_fk
  foreign key (shop_id, voided_by) references staff (shop_id, id);
alter table purchases add constraint purchases_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table purchases add constraint purchases_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table purchases add constraint purchases_entered_by_same_shop_fk
  foreign key (shop_id, entered_by) references staff (shop_id, id);
alter table stock_counts add constraint stock_counts_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table stock_counts add constraint stock_counts_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table stock_counts add constraint stock_counts_counted_by_same_shop_fk
  foreign key (shop_id, counted_by) references staff (shop_id, id);
alter table waste_logs add constraint waste_logs_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table waste_logs add constraint waste_logs_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table waste_logs add constraint waste_logs_entered_by_same_shop_fk
  foreign key (shop_id, entered_by) references staff (shop_id, id);
alter table stock_ledger add constraint stock_ledger_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table stock_ledger add constraint stock_ledger_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table stock_ledger add constraint stock_ledger_created_by_same_shop_fk
  foreign key (shop_id, created_by) references staff (shop_id, id);
alter table audit_log add constraint audit_log_actor_same_shop_fk
  foreign key (shop_id, actor) references staff (shop_id, id);
alter table pin_attempts add constraint pin_attempts_staff_same_shop_fk
  foreign key (shop_id, staff_id) references staff (shop_id, id);


-- >>> SOURCE: database/002_rules.sql
-- =====================================================================
-- Fore · 002_rules.sql · Luật bảo vệ dữ liệu
--  1) Bảng nhật ký/sổ kho CHỈ THÊM, không sửa/xóa (trigger chặn cả quản trị viên)
--  2) Nhật ký tự động cho thay đổi cấu hình (giá, công thức, nhân sự...)
--  3) Phân quyền theo vai trò bằng RLS + chỉ cấp quyền tối thiểu
--  Có hàm _setting(): đọc một con số cấu hình từ app_settings (các hàm sau dùng chung).
-- Chạy SAU 001_tables.sql.
-- =====================================================================

-- ---------- Hàm hỗ trợ ----------
-- (app_shop_id / app_staff_id / app_is_owner nằm ở 001_tables.sql vì cột shop_id dùng làm giá trị mặc định)

-- Con số cấu hình của quán (p_shop để trống = quán đang chọn của người gọi)
create or replace function _setting(p_key text, p_default integer, p_shop uuid default null) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select value_int from app_settings
                    where key = p_key and shop_id = coalesce(p_shop, app_shop_id())), p_default)
$$;

-- ---------- 1) Chỉ thêm, không sửa/xóa ----------
create or replace function prevent_mutation() returns trigger
language plpgsql as $$
begin
  raise exception 'Bảng % chỉ được thêm dòng mới, không được sửa hoặc xóa', tg_table_name
    using errcode = '42501';
end $$;

create trigger no_change_stock_ledger before update or delete on stock_ledger for each row execute function prevent_mutation();
create trigger no_change_stock_counts before update or delete on stock_counts for each row execute function prevent_mutation();
create trigger no_change_purchases    before update or delete on purchases    for each row execute function prevent_mutation();
create trigger no_change_waste_logs   before update or delete on waste_logs   for each row execute function prevent_mutation();
create trigger no_change_audit_log    before update or delete on audit_log    for each row execute function prevent_mutation();
create trigger no_change_pin_attempts before update or delete on pin_attempts for each row execute function prevent_mutation();

-- Không xóa các bảng có lịch sử (chỉ ẩn bằng active / đổi trạng thái)
create or replace function prevent_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'Không xóa dữ liệu bảng %. Hãy ẩn (active=false) hoặc đổi trạng thái', tg_table_name
    using errcode = '42501';
end $$;

create trigger no_delete_bills         before delete on bills         for each row execute function prevent_delete();
create trigger no_delete_bill_lines    before delete on bill_lines    for each row execute function prevent_delete();
create trigger no_delete_shifts        before delete on shifts        for each row execute function prevent_delete();
create trigger no_delete_shops         before delete on shops         for each row execute function prevent_delete();
create trigger no_delete_staff         before delete on staff         for each row execute function prevent_delete();
create trigger no_delete_ingredients   before delete on ingredients   for each row execute function prevent_delete();
create trigger no_delete_menu_items    before delete on menu_items    for each row execute function prevent_delete();
create trigger no_delete_menu_sizes    before delete on menu_sizes    for each row execute function prevent_delete();
create trigger no_delete_areas         before delete on areas         for each row execute function prevent_delete();
create trigger no_delete_dining_tables before delete on dining_tables for each row execute function prevent_delete();
create trigger no_delete_waste_types   before delete on waste_types   for each row execute function prevent_delete();

-- Hóa đơn: chỉ cho phép chuyển trạng thái hợp lệ, không đổi các trường gốc
create or replace function bills_guard() returns trigger
language plpgsql as $$
begin
  if new.id <> old.id or new.bill_no <> old.bill_no or new.shift_id <> old.shift_id
     or new.table_id is distinct from old.table_id or new.bill_type <> old.bill_type
     or new.opened_at <> old.opened_at or new.opened_by <> old.opened_by then
    raise exception 'Không được sửa thông tin gốc của bill' using errcode = '42501';
  end if;
  if new.status <> old.status and not (
       (old.status = 'open' and new.status in ('paid','cancelled')) or
       (old.status = 'paid' and new.status = 'cancelled')) then
    raise exception 'Chuyển trạng thái bill không hợp lệ: % -> %', old.status, new.status using errcode = '42501';
  end if;
  if old.status = 'cancelled' then
    raise exception 'Bill đã hủy không được sửa' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger bills_guard_trg before update on bills for each row execute function bills_guard();

-- Dòng bill: chỉ được đánh dấu hủy, không đổi số lượng/giá/món
create or replace function bill_lines_guard() returns trigger
language plpgsql as $$
begin
  if new.id <> old.id or new.bill_id <> old.bill_id or new.size_id <> old.size_id
     or new.qty <> old.qty or new.unit_price <> old.unit_price or old.voided_at is not null then
    raise exception 'Dòng bill chỉ được đánh dấu hủy, không được sửa' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger bill_lines_guard_trg before update on bill_lines for each row execute function bill_lines_guard();

-- ---------- 2) Nhật ký thay đổi cấu hình ----------
create or replace function audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old jsonb; v_new jsonb;
begin
  if tg_op in ('UPDATE','DELETE') then v_old := to_jsonb(old) - 'pin_hash'; end if;
  if tg_op in ('INSERT','UPDATE') then v_new := to_jsonb(new) - 'pin_hash'; end if;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
  values (coalesce((v_new->>'shop_id')::uuid, (v_old->>'shop_id')::uuid, app_shop_id()),
          app_staff_id(), lower(tg_op), tg_table_name,
          coalesce(v_new->>'id', v_old->>'id')::uuid,
          jsonb_build_object('old', v_old, 'new', v_new));
  return coalesce(new, old);
end $$;

create trigger audit_staff         after insert or update or delete on staff         for each row execute function audit_row_change();
create trigger audit_ingredients   after insert or update or delete on ingredients   for each row execute function audit_row_change();
create trigger audit_menu_items    after insert or update or delete on menu_items    for each row execute function audit_row_change();
create trigger audit_menu_sizes    after insert or update or delete on menu_sizes    for each row execute function audit_row_change();
-- Công thức của size ĐÃ TỪNG BÁN thì không được sửa/xóa/thêm dòng: số ly và tiền ước tính của các ca cũ
-- (reconcile_shift) tính theo công thức, đổi công thức sẽ làm sai quá khứ.
-- Muốn đổi: ẩn size cũ (menu_sizes.active = false) và tạo size mới với công thức mới.
create or replace function recipe_lines_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from bill_lines
              where size_id in (case when tg_op = 'INSERT' then new.size_id else old.size_id end,
                                case when tg_op = 'UPDATE' then new.size_id else old.size_id end)) then
    raise exception 'RECIPE_IN_USE';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
create trigger recipe_lines_guard before insert or update or delete on recipe_lines
  for each row execute function recipe_lines_guard();

create trigger audit_recipe_lines  after insert or update or delete on recipe_lines  for each row execute function audit_row_change();
create trigger audit_areas         after insert or update or delete on areas         for each row execute function audit_row_change();
create trigger audit_dining_tables after insert or update or delete on dining_tables for each row execute function audit_row_change();
create trigger audit_waste_types   after insert or update or delete on waste_types   for each row execute function audit_row_change();
create trigger audit_app_settings  after update on app_settings for each row execute function audit_row_change();

-- ---------- 3) Phân quyền (RLS) ----------
alter table shops          enable row level security;
alter table user_settings  enable row level security;
alter table shop_invites   enable row level security;
alter table staff          enable row level security;
alter table ingredients    enable row level security;
alter table menu_items     enable row level security;
alter table menu_sizes     enable row level security;
alter table recipe_lines   enable row level security;
alter table areas          enable row level security;
alter table dining_tables  enable row level security;
alter table shifts         enable row level security;
alter table bills          enable row level security;
alter table bill_lines     enable row level security;
alter table purchases      enable row level security;
alter table stock_counts   enable row level security;
alter table waste_logs     enable row level security;
alter table stock_ledger   enable row level security;
alter table audit_log      enable row level security;
alter table pin_attempts   enable row level security;
alter table app_settings   enable row level security;
alter table waste_types    enable row level security;

-- Thu hết quyền mặc định, rồi cấp lại tối thiểu
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

-- Quán: thành viên xem quán mình thuộc; chủ quán đang chọn được đổi tên. Tạo quán qua create_shop().
create or replace function _my_shop_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select shop_id from staff where auth_user_id = auth.uid() and active
$$;
revoke all on function _my_shop_ids() from public, anon;
grant execute on function _my_shop_ids() to authenticated;
grant select (id, name, created_at) on shops to authenticated;
grant update (name) on shops to authenticated;
create policy shops_read  on shops for select to authenticated using (id in (select _my_shop_ids()));
create policy shops_write on shops for update to authenticated
  using (id = (select app_shop_id()) and (select app_is_owner())) with check (id = (select app_shop_id()) and (select app_is_owner()));
-- user_settings: không cấp quyền trực tiếp (chọn quán qua select_shop()). Không policy nào = không ai đọc/ghi trực tiếp.

-- Lời mời: chủ của quán đang chọn xem được lời mời của quán. Người được mời đọc qua my_invites().
grant select on shop_invites to authenticated;
create policy shop_invites_owner_read on shop_invites for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Nhân sự: ai cũng xem được tên mình; chủ xem cả quán. KHÔNG cho đọc cột pin_hash.
-- Không cho thêm nhân sự trực tiếp: người vào quán chỉ qua create_shop() (chủ) hoặc accept_invite() (nhân viên chấp nhận lời mời).
grant select (id, shop_id, auth_user_id, full_name, role, active, created_at) on staff to authenticated;
grant update (full_name, role, active) on staff to authenticated;
create policy staff_read  on staff for select to authenticated
  using (shop_id = (select app_shop_id()) and ((select app_is_owner()) or auth_user_id = (select auth.uid())));
create policy staff_write on staff for update to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Cấu hình (nguyên liệu, menu, công thức, khu, bàn): nhân viên đọc, chủ ghi
grant select, insert, update on ingredients, menu_items, menu_sizes, areas, dining_tables to authenticated;
grant select, insert, update, delete on recipe_lines to authenticated;   -- sửa công thức = xóa/thêm dòng (có nhật ký)

create policy ingredients_read  on ingredients   for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy ingredients_write on ingredients   for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy menu_items_read   on menu_items    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy menu_items_write  on menu_items    for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy menu_sizes_read   on menu_sizes    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy menu_sizes_write  on menu_sizes    for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy recipe_lines_read  on recipe_lines  for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy recipe_lines_write on recipe_lines  for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy areas_read        on areas         for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy areas_write       on areas         for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy dining_tables_read  on dining_tables for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy dining_tables_write on dining_tables for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Thiết lập và loại hao hụt: nhân viên đọc, chủ ghi. Thiết lập chỉ được sửa GIÁ TRỊ (không đổi tên khóa, không xóa).
grant select on app_settings to authenticated;
grant update (value_int) on app_settings to authenticated;
create policy app_settings_read  on app_settings for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy app_settings_write on app_settings for update to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
grant select, insert on waste_types to authenticated;
grant update (label_vi, requires_note, active, sort_order) on waste_types to authenticated;
create policy waste_types_read  on waste_types for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy waste_types_write on waste_types for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Bán hàng: nhân viên chỉ ĐỌC trực tiếp. Mọi thao tác ghi đi qua hàm trong 003_actions.sql
grant select on shifts, bills, bill_lines to authenticated;
create policy shifts_read     on shifts     for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy bills_read      on bills      for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy bill_lines_read on bill_lines for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);

-- Kho và nhật ký: CHỈ CHỦ ĐỌC (để nhân viên không thấy số tồn dự kiến khi đếm mù)
grant select on purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts to authenticated;
create policy purchases_owner_read    on purchases    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy stock_counts_owner_read on stock_counts for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy waste_logs_owner_read   on waste_logs   for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy stock_ledger_owner_read on stock_ledger for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy audit_log_owner_read    on audit_log    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy pin_attempts_owner_read on pin_attempts for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- ---------- Quyền chạy hàm hỗ trợ (dùng trong policy) ----------
revoke all on function app_shop_id(), app_staff_id(), app_is_owner() from public, anon;
grant execute on function app_shop_id(), app_staff_id(), app_is_owner() to authenticated;


-- >>> SOURCE: database/003_actions.sql
-- =====================================================================
-- Fore · 003_actions.sql · Các thao tác nghiệp vụ (app gọi qua supabase.rpc)
-- Nhân viên KHÔNG ghi trực tiếp vào bảng bán hàng/kho; chỉ gọi các hàm này.
-- Lỗi nghiệp vụ trả về dạng mã chữ (ví dụ 'TABLE_HAS_OPEN_BILL') để app dịch ra tiếng Việt.
-- Chạy SAU 002_rules.sql.
-- =====================================================================

-- ---------- Hàm nội bộ ----------
create or replace function _require_staff() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := app_staff_id();
begin
  if v is null then raise exception 'NOT_STAFF'; end if;
  return v;
end $$;

create or replace function _require_owner() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := app_staff_id();
begin
  if v is null or not app_is_owner() then raise exception 'OWNER_ONLY'; end if;
  return v;
end $$;

create or replace function _open_shift_id() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  select id into v from shifts where status = 'open' and shop_id = app_shop_id();
  if v is null then raise exception 'NO_OPEN_SHIFT'; end if;
  return v;
end $$;

create or replace function _audit(p_action text, p_entity text, p_id uuid, p_detail jsonb default null) returns void
language sql security definer set search_path = public as $$
  insert into audit_log (actor, action, entity, entity_id, detail)
  values (app_staff_id(), p_action, p_entity, p_id, p_detail)
$$;

-- ---------- PIN ----------
create or replace function set_staff_pin(p_staff uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _require_owner();
  if p_pin !~ '^[0-9]{4,6}$' then raise exception 'PIN_FORMAT'; end if;
  update staff set pin_hash = crypt(p_pin, gen_salt('bf')) where id = p_staff and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('set_pin', 'staff', p_staff);
end $$;

-- Kiểm tra PIN chủ. Trả về id chủ nếu đúng; NULL nếu sai.
-- Sai liên tiếp quá pin_max_attempts lần trong pin_lock_minutes phút thì khóa (cả hai là con số trong app_settings).
-- (Không raise lỗi khi sai PIN để lần thử sai vẫn được ghi lại, không bị rollback.)
create or replace function _check_owner_pin(p_pin text, out owner_id uuid, out result text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_me uuid := _require_staff(); v_last_ok timestamptz; v_fail int;
        v_max int := _setting('pin_max_attempts', 3); v_lock int := _setting('pin_lock_minutes', 15);
begin
  select max(at) into v_last_ok from pin_attempts where staff_id = v_me and ok;
  select count(*) into v_fail from pin_attempts
   where staff_id = v_me and not ok and at > now() - make_interval(mins => v_lock)
     and (v_last_ok is null or at > v_last_ok);
  if v_fail >= v_max then result := 'PIN_LOCKED'; return; end if;

  select s.id into owner_id from staff s
   where s.shop_id = app_shop_id() and s.role = 'owner' and s.active and s.pin_hash is not null and s.pin_hash = crypt(p_pin, s.pin_hash)
   limit 1;
  insert into pin_attempts (staff_id, ok) values (v_me, owner_id is not null);
  result := case when owner_id is null then 'WRONG_PIN' else 'OK' end;
end $$;

-- ---------- Ca làm việc ----------
create or replace function open_shift(p_opening_cash integer default 0) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_id uuid;
begin
  if p_opening_cash is null or p_opening_cash < 0 then
    raise exception 'OPENING_CASH_INVALID';
  end if;
  begin
    insert into shifts (opened_by, opening_cash) values (v_me, p_opening_cash) returning id into v_id;
  exception when unique_violation then
    raise exception 'SHIFT_ALREADY_OPEN';
  end;
  perform _audit('open_shift', 'shifts', v_id, jsonb_build_object('opening_cash', p_opening_cash));
  return v_id;
end $$;

create or replace function close_shift(p_closing_cash integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_missing int;
begin
  if p_closing_cash is null or p_closing_cash < 0 then
    raise exception 'CLOSING_CASH_INVALID';
  end if;
  -- Khóa dòng ca (FOR UPDATE) trước khi kiểm tra: open_bill giữ khóa FOR SHARE cùng dòng này,
  -- nên không thể có bill mới chen vào giữa lúc kiểm tra và lúc đóng ca.
  perform 1 from shifts where id = v_shift and status = 'open' for update;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;   -- máy khác vừa đóng ca
  if exists (select 1 from bills where shift_id = v_shift and status = 'open') then
    raise exception 'OPEN_BILLS_REMAIN';   -- phải thanh toán hoặc hủy hết bill đang mở
  end if;
  -- Phải đếm kho cuối ca cho mọi nguyên liệu (trừ loại chỉ kiểm theo tuần)
  select count(*) into v_missing from ingredients i
   where i.shop_id = app_shop_id() and i.active and not i.weekly_check
     and not exists (select 1 from stock_counts c
                      where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = 'close');
  if v_missing > 0 then raise exception 'MISSING_CLOSE_COUNTS'; end if;

  update shifts set status = 'closed', closed_by = v_me, closed_at = now(), closing_cash = p_closing_cash
   where id = v_shift;
  perform _audit('close_shift', 'shifts', v_shift, jsonb_build_object('closing_cash', p_closing_cash));
  return v_shift;
end $$;

-- ---------- Bán hàng ----------
create or replace function open_bill(p_table uuid, p_type text, p_guests integer default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  -- Giữ khóa FOR SHARE trên ca và kiểm tra lại ca còn mở (đối ứng với FOR UPDATE trong close_shift)
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;
  if p_type = 'dine_in' and p_table is null then raise exception 'TABLE_REQUIRED'; end if;
  if p_table is not null and not exists (select 1 from dining_tables where id = p_table and shop_id = app_shop_id()) then
    raise exception 'TABLE_NOT_FOUND';
  end if;
  if p_type = 'take_away' then p_table := null; end if;
  begin
    insert into bills (shift_id, table_id, bill_type, guests, opened_by)
    values (v_shift, p_table, p_type, p_guests, v_me) returning id into v_id;
  exception when unique_violation then
    raise exception 'TABLE_HAS_OPEN_BILL';   -- bàn này đang có bill mở (máy khác vừa mở)
  end;
  return v_id;
end $$;

create or replace function add_bill_line(p_bill uuid, p_size uuid, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_status text; v_price integer; v_id uuid;
begin
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  select price into v_price from menu_sizes where id = p_size and active and shop_id = app_shop_id();
  if v_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;
  insert into bill_lines (bill_id, size_id, qty, unit_price, created_by)
  values (p_bill, p_size, p_qty, v_price, v_me) returning id into v_id;
  return v_id;
end $$;

create or replace function void_bill_line(p_line uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill uuid; v_status text;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select bill_id into v_bill from bill_lines where id = p_line and shop_id = app_shop_id();
  select status into v_status from bills where id = v_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  update bill_lines set voided_at = now(), voided_by = v_me, void_reason = p_reason
   where id = p_line and voided_at is null;
  perform _audit('void_line', 'bill_lines', p_line, jsonb_build_object('reason', p_reason, 'bill', v_bill));
end $$;

create or replace function set_bill_discount(p_bill uuid, p_discount integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_status text; v_sub integer;
begin
  perform _require_staff();
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  select coalesce(sum(qty * unit_price), 0) into v_sub from bill_lines where bill_id = p_bill and voided_at is null;
  if p_discount < 0 or p_discount > v_sub then raise exception 'DISCOUNT_INVALID'; end if;
  if p_discount > 0 and coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  update bills set discount = p_discount, discount_reason = p_reason where id = p_bill;
  perform _audit('discount', 'bills', p_bill, jsonb_build_object('discount', p_discount, 'reason', p_reason));
end $$;

-- Thanh toán. Cập nhật có điều kiện: nếu máy khác đã thanh toán thì báo BILL_NOT_OPEN.
create or replace function pay_bill(p_bill uuid, p_method text default 'cash') returns integer
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill bills%rowtype; v_sub integer; v_total integer; v_n integer;
begin
  if p_method is null or p_method not in ('cash', 'transfer') then
    raise exception 'PAYMENT_METHOD_INVALID';
  end if;
  select * into v_bill from bills where id = p_bill and shop_id = app_shop_id() for update;
  if not found or v_bill.status <> 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  select coalesce(sum(qty * unit_price), 0) into v_sub from bill_lines where bill_id = p_bill and voided_at is null;
  if v_sub = 0 then raise exception 'BILL_EMPTY'; end if;
  v_total := v_sub - v_bill.discount;

  update bills set status = 'paid', paid_at = now(), paid_by = v_me, payment_method = p_method, total_amount = v_total
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  -- Ghi sổ kho: mỗi dòng bán x công thức tại THỜI ĐIỂM bán (đổi công thức sau này không làm lệch ca cũ)
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale', -sum(l.qty * r.qty)::integer, p_bill, v_me
    from bill_lines l join recipe_lines r on r.size_id = l.size_id
   where l.bill_id = p_bill and l.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill, jsonb_build_object('total', v_total, 'method', p_method));
  return v_total;
end $$;

-- Hủy bill CHƯA thanh toán (cần lý do, ghi nhật ký)
create or replace function cancel_open_bill(p_bill uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_status text;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  update bills set status = 'cancelled', cancelled_by = v_me, cancelled_at = now(), cancel_reason = p_reason where id = p_bill;
  perform _audit('cancel_open', 'bills', p_bill, jsonb_build_object('reason', p_reason));
end $$;

-- Hủy bill ĐÃ thu tiền: chủ phải đứng đó nhập PIN trên máy nhân viên; chỉ trong ca hiện tại.
-- Trả về mã trạng thái: 'OK' | 'WRONG_PIN' | 'PIN_LOCKED'. Lỗi khác sẽ raise.
create or replace function cancel_paid_bill(p_bill uuid, p_owner_pin text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill bills%rowtype; v_pin record;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_bill from bills where id = p_bill and shop_id = app_shop_id() for update;
  if not found or v_bill.status <> 'paid' then raise exception 'BILL_NOT_PAID'; end if;
  if v_bill.shift_id <> _open_shift_id() then raise exception 'ONLY_CURRENT_SHIFT'; end if;

  select * into v_pin from _check_owner_pin(p_owner_pin);
  if v_pin.result <> 'OK' then return v_pin.result; end if;

  update bills set status = 'cancelled', cancelled_by = v_me, cancelled_at = now(),
                   cancel_reason = p_reason, approved_by = v_pin.owner_id
   where id = p_bill;
  -- Hoàn lại sổ kho đúng bằng các dòng đã ghi lúc bán
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select shift_id, ingredient_id, 'void_sale', -qty_delta, p_bill, v_me
    from stock_ledger where kind = 'sale' and ref_id = p_bill;
  perform _audit('cancel_paid', 'bills', p_bill,
                 jsonb_build_object('reason', p_reason, 'approved_by', v_pin.owner_id, 'amount', v_bill.total_amount));
  return 'OK';
end $$;

-- Đơn mang đi: đánh dấu đã làm xong
create or replace function mark_prep_done(p_bill uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_staff();
  update bills set prep_done_at = now()
   where id = p_bill and shop_id = app_shop_id() and bill_type = 'take_away' and status <> 'cancelled' and prep_done_at is null;
end $$;

-- ---------- Kho ----------
create or replace function add_purchase(p_ingredient uuid, p_qty integer, p_late boolean default false, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into purchases (shift_id, ingredient_id, qty, is_late_entry, note, entered_by)
  values (v_shift, p_ingredient, p_qty, p_late, p_note, v_me) returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'purchase', p_qty, v_id, v_me);
  return v_id;
end $$;

-- Kiểm kê MÙ: nhân viên nhập số đo thực tế, hàm này không trả về số dự kiến.
create or replace function submit_stock_count(p_ingredient uuid, p_kind text, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by)
  values (v_shift, p_ingredient, p_kind, p_qty, v_me) returning id into v_id;
  return v_id;
end $$;

-- Hao hụt: phải CHỌN LOẠI trong bảng waste_types (+ ghi chú). Loại có requires_note thì bắt buộc ghi chú.
-- Nguyên liệu tính theo đơn vị gốc (trân châu: gram KHÔ quy đổi).
create or replace function add_waste(p_ingredient uuid, p_qty integer, p_type text, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid; v_wt waste_types;
begin
  select * into v_wt from waste_types where code = p_type and active and shop_id = app_shop_id();

  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'NOTE_REQUIRED';
  end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into waste_logs (shift_id, ingredient_id, qty, reason_type, reason, entered_by)
  values (v_shift, p_ingredient, p_qty, p_type, coalesce(nullif(btrim(p_note), ''), v_wt.label_vi), v_me)
  returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'waste', -p_qty, v_id, v_me);
  return v_id;
end $$;

-- ---------- Cấp quyền chạy hàm ----------
-- Thu mọi quyền chạy hàm, rồi chỉ cấp cho các hàm app được gọi.
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant execute on function app_shop_id(), app_staff_id(), app_is_owner() to authenticated;   -- policy cần dùng
grant execute on function
  set_staff_pin(uuid, text),
  open_shift(integer), close_shift(integer),
  open_bill(uuid, text, integer), add_bill_line(uuid, uuid, integer), void_bill_line(uuid, text),
  set_bill_discount(uuid, integer, text), pay_bill(uuid, text),
  cancel_open_bill(uuid, text), cancel_paid_bill(uuid, text, text), mark_prep_done(uuid),
  add_purchase(uuid, integer, boolean, text), submit_stock_count(uuid, text, integer),
  add_waste(uuid, integer, text, text)
to authenticated;


-- >>> SOURCE: database/004_reconcile.sql
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


-- >>> SOURCE: database/005_cash_reconcile.sql
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


-- >>> SOURCE: database/006_waste_report.sql
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


-- >>> SOURCE: database/007_corrections.sql
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


-- >>> SOURCE: database/008_staff_setup.sql
-- =====================================================================
-- Fore · 008_staff_setup.sql · Tạo quán, mời nhân viên, chọn quán (NHIỀU QUÁN)
--
-- Quy trình:
--   1) CHỦ: đăng ký tài khoản rõ ràng (email + mật khẩu) qua Supabase Auth, rồi gọi create_shop(tên quán, tên hiển thị).
--      Người tạo quán trở thành chủ của quán đó. Một người có thể tạo/tham gia nhiều quán.
--   2) CHỦ mời nhân viên: invite_staff(số điện thoại, tên hiển thị[, email]).
--   3) NHÂN VIÊN: đăng nhập bằng số điện thoại (OTP, Supabase xác thực) hoặc email đã xác nhận.
--      Chưa có quán nào thì vào "không gian nhân viên trống" và thấy hộp thư: my_invites().
--      Chấp nhận accept_invite(id) thì trở thành thành viên và tải dữ liệu quán.
--   4) Người thuộc nhiều quán chọn quán bằng select_shop(); my_shops() liệt kê các quán.
--   5) Chủ đặt PIN bằng set_staff_pin (003). Nghỉ việc: đặt staff.active = false (không xóa).
--
-- BẢO MẬT: lời mời chỉ khớp với số điện thoại/email ĐÃ XÁC THỰC trong auth.users
-- (phone_confirmed_at / email_confirmed_at). Không tin số điện thoại do người dùng tự gõ vào app,
-- vì khi đó ai biết số nhân viên cũng có thể "đăng ký giùm" rồi nhận lời mời vào quán.
-- Chạy SAU 007_corrections.sql.
-- =====================================================================

-- Không cho khóa hoặc hạ quyền của chủ cuối cùng TRONG QUÁN (tránh quán không còn chủ)
create or replace function staff_guard() returns trigger
language plpgsql as $$
begin
  if old.role = 'owner' and old.active and (new.active = false or new.role <> 'owner') then
    if not exists (select 1 from staff s where s.shop_id = old.shop_id and s.role = 'owner' and s.active and s.id <> old.id) then
      raise exception 'LAST_OWNER' using errcode = '42501';
    end if;
  end if;
  if new.shop_id <> old.shop_id or new.auth_user_id is distinct from old.auth_user_id then
    raise exception 'Không được đổi quán hoặc tài khoản của thành viên' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger staff_guard_trg before update on staff for each row execute function staff_guard();

-- ---------- Số điện thoại ----------
-- Chuẩn hóa về dạng chỉ chữ số kèm mã quốc gia: '0901 234 567' -> '84901234567'; '+84901234567' -> '84901234567'.
-- Số bắt đầu bằng 0 được hiểu là số Việt Nam. Số nước khác: nhập đủ mã quốc gia (+1..., +44...).
create or replace function normalize_phone(p text) returns text
language sql immutable as $$
  select case
    when d = '' then null
    when btrim(coalesce(p, '')) like '+%' then d
    when d like '0%' then '84' || substr(d, 2)
    else d
  end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) x
$$;

-- Số điện thoại và email ĐÃ XÁC THỰC của người đang đăng nhập
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public as $$
begin
  select case when u.phone_confirmed_at is not null then normalize_phone(u.phone) end,
         case when u.email_confirmed_at is not null then lower(btrim(u.email)) end
    into phone, email
    from auth.users u where u.id = auth.uid();
end $$;

-- ---------- Tạo quán (chủ) ----------
create or replace function create_shop(p_shop_name text, p_owner_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_shop uuid;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if coalesce(btrim(p_shop_name), '') = '' then raise exception 'SHOP_NAME_REQUIRED'; end if;
  if coalesce(btrim(p_owner_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  insert into shops (name, created_by) values (btrim(p_shop_name), v_uid) returning id into v_shop;
  insert into staff (shop_id, auth_user_id, full_name, role) values (v_shop, v_uid, btrim(p_owner_name), 'owner');
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, v_shop)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  return v_shop;
end $$;

-- ---------- Các quán của tôi và chọn quán ----------
-- (Nâng cấp từ bản 1 quán: bỏ các hàm cũ)
drop function if exists claim_first_owner(text);
drop function if exists link_staff_account(text, text, text);
drop function if exists my_profile();

create or replace function my_shops()
returns table (shop_id uuid, shop_name text, staff_id uuid, role text, display_name text, is_current boolean)
language sql stable security definer set search_path = public as $$
  select s.shop_id, sh.name, s.id, s.role, s.full_name, s.shop_id = app_shop_id()
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = auth.uid() and s.active
   order by s.created_at
$$;

create or replace function select_shop(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if not exists (select 1 from staff where shop_id = p_shop and auth_user_id = v_uid and active) then
    raise exception 'NOT_STAFF';
  end if;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, p_shop)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
end $$;

-- Thông tin của tôi trong quán đang chọn (không có cột PIN). Không có dòng nào = chưa thuộc quán nào.
create or replace function my_profile()
returns table (staff_id uuid, full_name text, role text, has_pin boolean, active boolean, shop_id uuid, shop_name text)
language sql stable security definer set search_path = public as $$
  select s.id, s.full_name, s.role, s.pin_hash is not null, s.active, s.shop_id, sh.name
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = auth.uid() and s.shop_id = app_shop_id()
$$;

-- ---------- Mời nhân viên (chủ) ----------
create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_phone text := normalize_phone(p_phone); v_email text := nullif(lower(btrim(p_email)), '');
        v_id uuid;
begin
  if v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$' then raise exception 'PHONE_INVALID'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  -- đã là thành viên đang hoạt động của quán này?
  if exists (select 1 from staff s join auth.users u on u.id = s.auth_user_id
              where s.shop_id = app_shop_id() and s.active
                and ((u.phone_confirmed_at is not null and normalize_phone(u.phone) = v_phone)
                  or (v_email is not null and u.email_confirmed_at is not null and lower(u.email) = v_email))) then
    raise exception 'ALREADY_MEMBER';
  end if;
  begin
    insert into shop_invites (shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me) returning id into v_id;
  exception when unique_violation then
    raise exception 'ALREADY_INVITED';
  end;
  perform _audit('invite_staff', 'shop_invites', v_id, jsonb_build_object('phone', v_phone, 'name', btrim(p_full_name)));
  return v_id;
end $$;

create or replace function cancel_invite(p_invite uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  update shop_invites set status = 'cancelled', responded_at = now()
   where id = p_invite and shop_id = app_shop_id() and status = 'pending';
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('cancel_invite', 'shop_invites', p_invite);
end $$;

-- Danh sách thành viên của quán đang chọn, kèm số điện thoại/email (chủ xem)
create or replace function shop_team()
returns table (staff_id uuid, full_name text, role text, active boolean, phone text, email text, has_pin boolean, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return query
    select s.id, s.full_name, s.role, s.active, u.phone::text, u.email::text, s.pin_hash is not null, s.created_at
      from staff s left join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
     order by (s.role = 'owner') desc, s.active desc, s.created_at;
end $$;

-- ---------- Hộp thư của nhân viên ----------
-- Lời mời đang chờ gửi tới số điện thoại/email ĐÃ XÁC THỰC của người đang đăng nhập
create or replace function my_invites()
returns table (invite_id uuid, shop_id uuid, shop_name text, invited_name text, invited_by_name text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare v_phone text; v_email text;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  return query
    select i.id, i.shop_id, sh.name, i.full_name, inv.full_name, i.created_at
      from shop_invites i
      join shops sh on sh.id = i.shop_id
      join staff inv on inv.id = i.invited_by
     where i.status = 'pending'
       and ((v_phone is not null and i.phone = v_phone) or (v_email is not null and i.email = v_email))
     order by i.created_at desc;
end $$;

-- Hàm dùng chung: lời mời có thật sự gửi cho tôi không (đang chờ)
create or replace function _invite_for_me(p_invite uuid) returns shop_invites
language plpgsql security definer set search_path = public as $$
declare v_phone text; v_email text; r shop_invites;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  select * into r from shop_invites i
   where i.id = p_invite and i.status = 'pending'
     and ((v_phone is not null and i.phone = v_phone) or (v_email is not null and i.email = v_email))
   for update;
  if not found then raise exception 'INVITE_NOT_FOUND'; end if;   -- không tồn tại, đã xử lý, hoặc không phải của tôi
  return r;
end $$;

-- Chấp nhận: trở thành nhân viên của quán và chuyển sang quán đó
create or replace function accept_invite(p_invite uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); r shop_invites; v_staff uuid;
begin
  r := _invite_for_me(p_invite);
  select id into v_staff from staff where shop_id = r.shop_id and auth_user_id = v_uid;
  if v_staff is null then
    insert into staff (shop_id, auth_user_id, full_name, role) values (r.shop_id, v_uid, r.full_name, 'staff')
      returning id into v_staff;
  else   -- đã từng làm ở quán này và bị ẩn: kích hoạt lại với vai trò nhân viên
    update staff set active = true, role = 'staff', full_name = r.full_name where id = v_staff and not active;
  end if;
  update shop_invites set status = 'accepted', responded_at = now(), accepted_user_id = v_uid where id = r.id;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, r.shop_id)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
    values (r.shop_id, v_staff, 'accept_invite', 'shop_invites', r.id, null);
  return v_staff;
end $$;

create or replace function decline_invite(p_invite uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r shop_invites;
begin
  r := _invite_for_me(p_invite);
  update shop_invites set status = 'declined', responded_at = now() where id = r.id;
end $$;

-- ---------- Quyền chạy hàm ----------
revoke all on function _my_verified_contacts(), _invite_for_me(uuid) from public, anon, authenticated;
revoke all on function normalize_phone(text), create_shop(text, text), my_shops(), select_shop(uuid), my_profile(),
  invite_staff(text, text, text), cancel_invite(uuid), shop_team(), my_invites(), accept_invite(uuid), decline_invite(uuid)
  from public, anon;
grant execute on function normalize_phone(text), create_shop(text, text), my_shops(), select_shop(uuid), my_profile(),
  invite_staff(text, text, text), cancel_invite(uuid), shop_team(), my_invites(), accept_invite(uuid), decline_invite(uuid)
  to authenticated;


-- >>> SOURCE: database/009_shift_report.sql
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


-- >>> SOURCE: database/010_current_shift.sql
-- =====================================================================
-- Fore · 010_current_shift.sql · Xem ca đang mở (cho MỌI nhân viên)
-- Cả quán chỉ có tối đa 1 ca mở. Người đến sau cần biết "ca đang mở, ai mở, lúc nào,
-- có phải mình mở không, còn mấy bill đang mở" để bấm "Vào ca" thay vì "Mở ca".
-- Nhân viên không đọc được bảng staff nên cần hàm này. Hàm KHÔNG trả số tiền đầu ca
-- và không trả doanh thu (nhân viên không cần thấy).
-- Chạy SAU 009. Gọi từ app: supabase.rpc('current_shift'). Không có ca mở thì trả 0 dòng.
-- Chạy lại nhiều lần được (drop trước khi tạo, vì đổi số cột trả về).
-- =====================================================================

drop function if exists current_shift();

create function current_shift()
returns table (
  shift_id        uuid,
  opened_by_name  text,
  opened_at       timestamptz,   -- giờ máy chủ
  opened_by_me    boolean,       -- người gọi chính là người mở ca
  open_bills      integer        -- số bill đang mở trong ca (trước khi đóng ca phải xử lý hết)
)
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff();   -- NOT_STAFF nếu không phải nhân viên đang hoạt động
begin
  return query
    select s.id,
           st.full_name,
           s.opened_at,
           s.opened_by = v_me,
           (select count(*)::integer from bills b where b.shift_id = s.id and b.status = 'open')
      from shifts s
      join staff st on st.id = s.opened_by
     where s.status = 'open' and s.shop_id = app_shop_id();
end $$;

revoke all on function current_shift() from public, anon;
grant execute on function current_shift() to authenticated;


-- >>> SOURCE: database/011_app_read_api.sql
-- =====================================================================
-- Fore · 011_app_read_api.sql · API đọc cho app nhiều quán
-- Chạy SAU 010_current_shift.sql, MỘT lần trong SQL Editor. Chạy lại cũng an toàn.
--
-- Vì sao cần: các màn hình thiết kế (bản đồ bàn, đơn mang đi, đóng ca) cần dữ liệu mà bảng gốc không trả
-- trực tiếp hoặc trả không an toàn cho nhân viên:
--   · tên quán theo quán đang chọn                               -> shop_info()
--   · "Ca của An, mở lúc 8:02" (RLS chỉ cho nhân viên thấy tên mình) -> current_shift()  (KHÔNG trả tiền)
--   · số phần đang gọi trên từng bàn                            -> table_map()
--   · danh sách đơn mang đi chưa xong, cũ nhất ở trên           -> takeaway_orders()
--   · danh sách việc trước khi đóng ca (đếm mù: chỉ trả SỐ LƯỢNG, không trả số đo) -> shift_close_status()
--   · thực đơn, chi tiết bill, phiếu kiểm kê, danh mục nhập/hao hụt -> menu_for_sale(), bill_detail(), count_sheet(), ...
-- Mọi hàm đọc là security definer: app không phụ thuộc quyền đọc bảng, nên sau này siết quyền đọc của nhân viên
-- (đợt rà soát A1/A2) cũng không làm app hỏng. Không hàm nào trả công thức, tồn kho, ngưỡng cảnh báo hay tiền két.
--
-- Luồng tạo/chọn quán đã có trong 008_staff_setup.sql; migration này chỉ thêm API đọc cho app.
-- =====================================================================

-- ---------- Sắp xếp khu và bàn ----------
alter table areas         add column if not exists sort_order integer not null default 0;
alter table dining_tables add column if not exists sort_order integer not null default 0;

-- Hồ sơ quán theo quán đang chọn; giữ nguyên mô hình nhiều quán của dự án.
create or replace function shop_info()
returns table (shop_name text, shop_type text, serving_label text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query select sh.name, 'drink'::text, 'phần'::text from shops sh where sh.id = app_shop_id();
end $$;
-- Việc còn thiếu trước khi đóng ca. Chỉ trả SỐ LƯỢNG; không lộ nguyên liệu nào đã đếm bao nhiêu.
create or replace function shift_close_status()
returns table (open_bills integer, missing_counts integer)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  v_shift := _open_shift_id();
  return query select
    (select count(*)::integer from bills b where b.shift_id = v_shift and b.status = 'open'),
    (select count(*)::integer from ingredients i
      where i.active and i.shop_id = app_shop_id() and not i.weekly_check
        and not exists (select 1 from stock_counts c
                         where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = 'close'));
end $$;

-- Bản đồ bàn: mỗi bàn đang dùng được một bill (nếu có) kèm tổng số phần đang gọi.
create or replace function table_map()
returns table (area_id uuid, area_name text, table_id uuid, table_name text,
               bill_id uuid, bill_no bigint, portions integer, guests integer, bill_opened_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select a.id, a.name, t.id, t.name, b.id, b.bill_no, coalesce(l.portions, 0)::integer, b.guests, b.opened_at
      from dining_tables t
      join areas a on a.id = t.area_id
      left join bills b on b.table_id = t.id and b.status = 'open'
      left join lateral (select sum(bl.qty) as portions from bill_lines bl
                          where bl.bill_id = b.id and bl.voided_at is null) l on true
     where t.active and a.active and t.shop_id = app_shop_id() and a.shop_id = app_shop_id()
     order by a.sort_order, a.name, t.sort_order,
              nullif(left(regexp_replace(t.name, '\D', '', 'g'), 9), '')::integer nulls last, t.name;
end $$;

-- Đơn mang đi của ca đang mở mà chưa làm xong (đã thu tiền hay chưa đều hiện). Cũ nhất ở trên.
create or replace function takeaway_orders()
returns table (bill_id uuid, bill_no bigint, status text, opened_at timestamptz, portions integer, items text)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  select s.id into v_shift from shifts s where s.status = 'open' and s.shop_id = app_shop_id();
  return query
    select b.id, b.bill_no, b.status, b.opened_at,
           coalesce((select sum(bl.qty) from bill_lines bl where bl.bill_id = b.id and bl.voided_at is null), 0)::integer,
           coalesce((select string_agg(x.name, ', ' order by x.first_at)
                       from (select mi.name, min(bl.created_at) as first_at
                               from bill_lines bl
                               join menu_sizes ms on ms.id = bl.size_id
                               join menu_items mi on mi.id = ms.item_id
                              where bl.bill_id = b.id and bl.voided_at is null
                              group by mi.name) x), '')
      from bills b
     where b.shop_id = app_shop_id() and b.shift_id = v_shift and b.bill_type = 'take_away'
       and b.prep_done_at is null and b.status <> 'cancelled'
     order by b.opened_at, b.bill_no;
end $$;

-- Thực đơn đang bán (món và size đều đang bật). Không có công thức.
create or replace function menu_for_sale()
returns table (item_id uuid, item_name text, group_name text, size_id uuid, size_name text, price integer)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select mi.id, mi.name, mi.group_name, ms.id, ms.size_name, ms.price
      from menu_items mi join menu_sizes ms on ms.item_id = mi.id
     where mi.active and ms.active and mi.shop_id = app_shop_id() and ms.shop_id = app_shop_id()
     order by mi.group_name nulls last, mi.name, ms.price, ms.size_name;
end $$;

-- Chi tiết một bill (màn gọi món / thanh toán). Số tiền tính ở database, app chỉ hiển thị.
create or replace function bill_detail(p_bill uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_bill record; v_lines jsonb; v_sub bigint; v_payable bigint;
begin
  perform _require_staff();
  select b.id, b.bill_no, b.status, b.bill_type, b.table_id, b.guests, b.opened_at, b.discount, b.discount_reason,
         b.total_amount, b.payment_method, b.prep_done_at, t.name as table_name, a.name as area_name
    into v_bill
    from bills b
    left join dining_tables t on t.id = b.table_id
    left join areas a on a.id = t.area_id
   where b.id = p_bill and b.shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
                    'id', l.id, 'size_id', l.size_id, 'item_name', mi.name, 'size_name', ms.size_name,
                    'qty', l.qty, 'unit_price', l.unit_price, 'voided', l.voided_at is not null)
                  order by l.created_at, l.id), '[]'::jsonb),
         coalesce(sum(l.qty::bigint * l.unit_price) filter (where l.voided_at is null), 0)
    into v_lines, v_sub
    from bill_lines l
    join menu_sizes ms on ms.id = l.size_id
    join menu_items mi on mi.id = ms.item_id
   where l.bill_id = p_bill;

  v_payable := case when v_bill.status = 'open' then greatest(v_sub - v_bill.discount, 0)
                    else coalesce(v_bill.total_amount, 0) end;
  return jsonb_build_object(
    'id', v_bill.id, 'bill_no', v_bill.bill_no, 'status', v_bill.status, 'bill_type', v_bill.bill_type,
    'table_id', v_bill.table_id, 'table_name', v_bill.table_name, 'area_name', v_bill.area_name,
    'guests', v_bill.guests, 'opened_at', v_bill.opened_at, 'discount', v_bill.discount,
    'discount_reason', v_bill.discount_reason, 'payment_method', v_bill.payment_method,
    'prep_done', v_bill.prep_done_at is not null,
    'lines', v_lines, 'subtotal', v_sub, 'payable', v_payable);
end $$;

-- Phiếu kiểm kê: danh sách nguyên liệu cần đếm. ĐẾM MÙ: chỉ có cờ "đã đếm", KHÔNG có số đã nhập, số dự kiến hay tồn.
create or replace function count_sheet(p_kind text)
returns table (ingredient_id uuid, name text, unit text, importance text, weekly_check boolean, group_name text, counted boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  if p_kind is null or p_kind not in ('open', 'close') then raise exception 'KIND_INVALID'; end if;
  v_shift := _open_shift_id();
  return query
    select i.id, i.name, i.unit, i.importance, i.weekly_check, i.group_name,
           exists (select 1 from stock_counts c
                    where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = p_kind)
      from ingredients i
     where i.active and i.shop_id = app_shop_id()
     order by (i.importance = 'important') desc, i.weekly_check, i.group_name nulls last, i.name;
end $$;

-- Danh mục cho phiếu nhập hàng / ghi hao hụt.
create or replace function ingredient_list()
returns table (ingredient_id uuid, name text, unit text, importance text, group_name text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select i.id, i.name, i.unit, i.importance, i.group_name
      from ingredients i where i.active and i.shop_id = app_shop_id()
     order by i.group_name nulls last, i.name;
end $$;

create or replace function waste_type_list()
returns table (code text, label_vi text, requires_note boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select w.code, w.label_vi, w.requires_note from waste_types w where w.active and w.shop_id = app_shop_id() order by w.sort_order, w.label_vi;
end $$;

-- Các truy vấn có SECURITY DEFINER đều lọc theo quán đang chọn.
revoke all on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  from public, anon;
grant execute on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  to authenticated;


-- >>> SOURCE: database/012_owner_dashboard.sql
-- =====================================================================

-- Ngưỡng tồn thấp là dữ liệu cấu hình mới; thêm an toàn cho project đã cài 001–011.
alter table ingredients
  add column if not exists min_stock_qty integer not null default 0
  check (min_stock_qty >= 0);
-- Fore · 012_owner_dashboard.sql · Tổng quan chỉ dành cho chủ quán
-- Chạy sau 011_app_read_api.sql. Dữ liệu doanh thu và báo cáo không được đọc
-- trực tiếp từ app: hàm kiểm tra vai trò chủ trước khi trả dữ liệu tổng hợp.
-- =====================================================================

create table if not exists owner_shift_reviews (
  shop_id    uuid not null references shops(id),
  shift_id   uuid not null,
  handled    boolean not null default false,
  note       text check (note is null or char_length(note) <= 1000),
  updated_by uuid not null,
  updated_at timestamptz not null default now(),
  primary key (shop_id, shift_id),
  foreign key (shop_id, shift_id) references shifts (shop_id, id),
  foreign key (shop_id, updated_by) references staff (shop_id, id)
);
revoke all on owner_shift_reviews from public, anon, authenticated;

create table if not exists owner_notification_reads (
  shop_id uuid not null references shops(id),
  notification_key text not null check (char_length(notification_key) <= 80),
  read_by uuid not null,
  read_at timestamptz not null default now(),
  primary key (shop_id, notification_key),
  foreign key (shop_id, read_by) references staff (shop_id, id)
);
revoke all on owner_notification_reads from public, anon, authenticated;

create or replace function set_shift_review(
  p_shift uuid, p_handled boolean, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_me uuid := app_staff_id();
begin
  if v_shop is null or v_me is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if p_handled is null then raise exception 'REVIEW_STATUS_INVALID'; end if;
  if char_length(coalesce(btrim(p_note), '')) > 1000 then
    raise exception 'NOTE_TOO_LONG';
  end if;
  if not exists (select 1 from shifts s
                  where s.id = p_shift and s.shop_id = v_shop and s.status = 'closed') then
    raise exception 'NOT_FOUND';
  end if;
  insert into owner_shift_reviews (shop_id, shift_id, handled, note, updated_by)
  values (v_shop, p_shift, p_handled, nullif(btrim(p_note), ''), v_me)
  on conflict (shop_id, shift_id) do update
    set handled = excluded.handled,
        note = excluded.note,
        updated_by = excluded.updated_by,
        updated_at = now();
end $$;

revoke all on function set_shift_review(uuid, boolean, text) from public, anon;
grant execute on function set_shift_review(uuid, boolean, text) to authenticated;

create or replace function mark_owner_notifications_read(p_keys text[])
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_me uuid := app_staff_id();
  v_key text;
  v_count integer := 0;
  v_id uuid;
begin
  if v_shop is null or v_me is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if coalesce(cardinality(p_keys), 0) > 100 then
    raise exception 'TOO_MANY_NOTIFICATIONS';
  end if;

  foreach v_key in array coalesce(p_keys, '{}'::text[]) loop
    if v_key like 'invite:%' then
      begin v_id := substring(v_key from 8)::uuid;
      exception when invalid_text_representation then continue; end;
      if not exists (select 1 from shop_invites i
                      where i.id = v_id and i.shop_id = v_shop
                        and i.status in ('pending','accepted','declined')) then
        continue;
      end if;
    elsif v_key like 'shift:%' then
      begin v_id := substring(v_key from 7)::uuid;
      exception when invalid_text_representation then continue; end;
      if not exists (select 1 from shifts s
                      where s.id = v_id and s.shop_id = v_shop and s.status = 'closed') then
        continue;
      end if;
    else
      continue;
    end if;

    insert into owner_notification_reads(shop_id, notification_key, read_by)
    values (v_shop, v_key, v_me)
    on conflict (shop_id, notification_key) do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end $$;

revoke all on function mark_owner_notifications_read(text[]) from public, anon;
grant execute on function mark_owner_notifications_read(text[]) to authenticated;

create or replace function owner_dashboard(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_open jsonb;
  v_reports jsonb;
  v_cash bigint;
  v_transfer bigint;
  v_yesterday bigint;
  v_bills integer;
  v_invites integer;
  v_missing integer;
  v_staff_active integer := 0;
  v_low_stock jsonb;
  v_notifications jsonb := '[]'::jsonb;
  v_event jsonb;
  v_key text;
  v_read boolean;
begin
  if v_shop is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '36 hours' then
    raise exception 'DATE_RANGE_INVALID';
  end if;

  select jsonb_build_object(
           'id', s.id,
           'opened_at', s.opened_at,
           'opened_by_name', st.full_name)
    into v_open
    from shifts s
    join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
   where s.shop_id = v_shop and s.status = 'open'
   limit 1;

  if v_open is not null then
    select count(distinct b.opened_by)::integer into v_staff_active
      from bills b
     where b.shop_id = v_shop
       and b.shift_id = (v_open ->> 'id')::uuid
       and b.status <> 'cancelled';
  end if;

  select count(*)::integer,
         coalesce(sum(b.total_amount) filter (where b.payment_method = 'cash'), 0)::bigint,
         coalesce(sum(b.total_amount) filter (where b.payment_method = 'transfer'), 0)::bigint
    into v_bills, v_cash, v_transfer
    from bills b
   where b.shop_id = v_shop and b.status = 'paid'
     and b.paid_at >= p_from and b.paid_at < p_to;

  select coalesce(sum(b.total_amount), 0)::bigint into v_yesterday
    from bills b
   where b.shop_id = v_shop and b.status = 'paid'
     and b.paid_at >= p_from - interval '1 day'
     and b.paid_at < p_to - interval '1 day';

  select count(*)::integer into v_invites
    from shop_invites i where i.shop_id = v_shop and i.status = 'pending';

  select count(*)::integer into v_missing
    from menu_sizes ms
    join menu_items mi on mi.id = ms.item_id and mi.shop_id = ms.shop_id
   where ms.shop_id = v_shop and ms.active and mi.active
     and not exists (select 1 from recipe_lines rl
                      where rl.shop_id = v_shop and rl.size_id = ms.id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'ingredient_id', i.id,
           'name', i.name,
           'unit', i.unit,
           'expected_qty', e.expected_qty,
           'minimum_qty', i.min_stock_qty)
           order by (i.importance = 'important') desc, i.name), '[]'::jsonb)
    into v_low_stock
    from ingredients i
    join v_expected_stock e on e.ingredient_id = i.id
   where i.shop_id = v_shop and i.active and i.min_stock_qty > 0
     and e.expected_qty is not null and e.expected_qty <= i.min_stock_qty;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'shift', jsonb_build_object(
               'id', recent.id,
               'status', recent.status,
               'opened_at', recent.opened_at,
               'closed_at', recent.closed_at,
               'opened_by_name', recent.opened_by_name),
             'review', jsonb_build_object(
               'handled', coalesce(recent.handled, false),
               'note', recent.note),
             'report', case when recent.status = 'closed'
                            then shift_report(recent.id)
                            else null end)
           order by recent.opened_at desc), '[]'::jsonb)
    into v_reports
    from (
      select s.id, s.status, s.opened_at, s.closed_at, st.full_name as opened_by_name,
             r.handled, r.note
        from shifts s
        join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
        left join owner_shift_reviews r on r.shop_id = s.shop_id and r.shift_id = s.id
       where s.shop_id = v_shop
       order by s.opened_at desc
       limit 3
    ) recent;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', 'invite:' || i.id::text,
           'kind', 'invite',
           'title', case i.status
             when 'accepted' then i.full_name || ' đã nhận lời mời'
             when 'declined' then i.full_name || ' đã từ chối lời mời'
             else 'Lời mời nhân viên đang chờ' end,
           'body', case i.status
             when 'accepted' then i.full_name || ' đã tham gia quán với vai trò nhân viên.'
             when 'declined' then 'Lời mời tham gia quán không được nhận.'
             else 'Đang chờ ' || i.full_name || ' phản hồi lời mời.' end,
           'occurred_at', coalesce(i.responded_at, i.created_at),
           'read', exists (select 1 from owner_notification_reads nr
                            where nr.shop_id = v_shop
                              and nr.notification_key = 'invite:' || i.id::text)
         ) order by coalesce(i.responded_at, i.created_at) desc), '[]'::jsonb)
    into v_notifications
    from (
      select * from shop_invites
       where shop_id = v_shop and status in ('pending','accepted','declined')
       order by coalesce(responded_at, created_at) desc limit 20
    ) i;

  for v_event in select value from jsonb_array_elements(v_reports) loop
    if coalesce(v_event -> 'report' -> 'summary' ->> 'overall', '') not in ('warn', 'alert')
       or coalesce((v_event -> 'review' ->> 'handled')::boolean, false) then
      continue;
    end if;
    v_key := 'shift:' || (v_event -> 'shift' ->> 'id');
    select exists (select 1 from owner_notification_reads nr
                    where nr.shop_id = v_shop and nr.notification_key = v_key)
      into v_read;
    v_notifications := v_notifications || jsonb_build_array(jsonb_build_object(
      'id', v_key,
      'kind', 'shift',
      'title', 'Ca vừa đóng có chênh lệch',
      'body', 'Ca của ' || coalesce(v_event -> 'shift' ->> 'opened_by_name', 'nhân viên')
             || ' cần được kiểm tra đối soát.',
      'occurred_at', v_event -> 'shift' ->> 'closed_at',
      'read', v_read));
  end loop;

  return jsonb_build_object(
    'open_shift', v_open,
    'cash_sales', v_cash,
    'transfer_sales', v_transfer,
    'yesterday_sales', v_yesterday,
    'bill_count', v_bills,
    'pending_invites', v_invites,
    'missing_recipe_count', v_missing,
    'active_staff_count', v_staff_active,
    'low_stock', v_low_stock,
    'notifications', v_notifications,
    'reports', v_reports);
end $$;

revoke all on function owner_dashboard(timestamptz, timestamptz) from public, anon;
grant execute on function owner_dashboard(timestamptz, timestamptz) to authenticated;


-- >>> SOURCE: database/013_staff_birth_date.sql
-- Fore · 013_staff_birth_date.sql
-- Thêm ngày sinh hồ sơ nhân viên và đồng bộ khi họ nhận lời mời.
-- Chạy sau 012_owner_dashboard.sql; không cần reset dữ liệu.

alter table staff add column if not exists birth_date date;

create or replace function accept_invite(p_invite uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  r shop_invites;
  v_staff uuid;
  v_name text;
  v_birth_date date;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  r := _invite_for_me(p_invite);
  v_name := coalesce(nullif(btrim(auth.jwt() -> 'user_metadata' ->> 'full_name'), ''), r.full_name);
  begin
    v_birth_date := nullif(auth.jwt() -> 'user_metadata' ->> 'birth_date', '')::date;
  exception when invalid_datetime_format then
    raise exception 'BIRTH_DATE_INVALID';
  end;

  select id into v_staff from staff where shop_id = r.shop_id and auth_user_id = v_uid;
  if v_staff is null then
    insert into staff (shop_id, auth_user_id, full_name, birth_date, role)
    values (r.shop_id, v_uid, v_name, v_birth_date, 'staff')
    returning id into v_staff;
  else
    update staff
       set active = true, role = 'staff', full_name = v_name,
           birth_date = coalesce(v_birth_date, birth_date)
     where id = v_staff;
  end if;

  update shop_invites set status = 'accepted', responded_at = now(), accepted_user_id = v_uid where id = r.id;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, r.shop_id)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
    values (r.shop_id, v_staff, 'accept_invite', 'shop_invites', r.id, null);
  return v_staff;
end $$;

revoke all on function accept_invite(uuid) from public, anon;
grant execute on function accept_invite(uuid) to authenticated;


-- >>> SOURCE: database/014_invite_phone_or_email.sql
-- Cho phép chủ mời nhân viên bằng điện thoại, email hoặc cả hai.
-- Chạy sau 013_staff_birth_date.sql.
alter table shop_invites alter column phone drop not null;
drop index if exists one_pending_invite;
create unique index if not exists one_pending_invite_phone
  on shop_invites (shop_id, phone) where status = 'pending' and phone is not null;
create unique index if not exists one_pending_invite_email
  on shop_invites (shop_id, email) where status = 'pending' and email is not null;

create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case when nullif(btrim(p_phone), '') is null then null else normalize_phone(p_phone) end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  if v_phone is null and v_email is null then raise exception 'CONTACT_REQUIRED'; end if;
  if v_phone is not null and v_phone !~ '^[1-9][0-9]{7,14}$' then raise exception 'PHONE_INVALID'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if exists (
    select 1 from staff s join auth.users u on u.id = s.auth_user_id
    where s.shop_id = app_shop_id() and s.active and (
      (v_phone is not null and u.phone_confirmed_at is not null and normalize_phone(u.phone) = v_phone)
      or (v_email is not null and u.email_confirmed_at is not null and lower(u.email) = v_email)))
  then raise exception 'ALREADY_MEMBER'; end if;
  begin
    insert into shop_invites (shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me) returning id into v_id;
  exception when unique_violation then raise exception 'ALREADY_INVITED';
  end;
  perform _audit('invite_staff', 'shop_invites', v_id,
    jsonb_build_object('phone', v_phone, 'email', v_email, 'name', btrim(p_full_name)));
  return v_id;
end $$;
revoke all on function invite_staff(text, text, text) from public, anon;
grant execute on function invite_staff(text, text, text) to authenticated;


-- >>> SOURCE: database/015_staff_demo_contacts.sql
-- TEST ONLY: let passwordless-style demo accounts match invitations by metadata.
-- App stores demo_phone/demo_email after creating an internal Supabase Auth session.
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public, auth as $$
declare v_meta jsonb;
begin
  select u.raw_user_meta_data into v_meta from auth.users u where u.id = auth.uid();
  phone := coalesce(
    (select normalize_phone(u.phone) from auth.users u where u.id = auth.uid() and u.phone_confirmed_at is not null),
    normalize_phone(v_meta ->> 'demo_phone'));
  email := coalesce(
    (select lower(btrim(u.email)) from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null),
    nullif(lower(btrim(v_meta ->> 'demo_email')), ''));
end $$;
revoke all on function _my_verified_contacts() from public, anon, authenticated;

-- Test identity contact must also prevent inviting the same account twice.
create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case when nullif(btrim(p_phone), '') is null then null else normalize_phone(p_phone) end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  if v_phone is null and v_email is null then raise exception 'CONTACT_REQUIRED'; end if;
  if v_phone is not null and v_phone !~ '^[1-9][0-9]{7,14}$' then raise exception 'PHONE_INVALID'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if exists (select 1 from staff s join auth.users u on u.id=s.auth_user_id
    where s.shop_id=app_shop_id() and s.active and (
      (v_phone is not null and (normalize_phone(u.phone)=v_phone or normalize_phone(u.raw_user_meta_data->>'demo_phone')=v_phone))
      or (v_email is not null and (lower(u.email)=v_email or lower(u.raw_user_meta_data->>'demo_email')=v_email))))
  then raise exception 'ALREADY_MEMBER'; end if;
  begin
    insert into shop_invites(shop_id,phone,email,full_name,invited_by)
    values(app_shop_id(),v_phone,v_email,btrim(p_full_name),v_me) returning id into v_id;
  exception when unique_violation then raise exception 'ALREADY_INVITED'; end;
  perform _audit('invite_staff','shop_invites',v_id,jsonb_build_object('phone',v_phone,'email',v_email,'name',btrim(p_full_name)));
  return v_id;
end $$;
revoke all on function invite_staff(text,text,text) from public, anon;
grant execute on function invite_staff(text,text,text) to authenticated;

-- >>> Integrated source: database/017_staff_invite_contact_fallback.sql
-- Fore · 017_staff_invite_contact_fallback.sql
-- Sửa hộp thư lời mời cho tài khoản nhân viên tạo trước khi app lưu demo contact metadata.
-- Chạy sau 015_simple_staff_login.sql và 016_audit_actor_same_shop.sql.
-- Không thay đổi dữ liệu hiện có; lời mời pending sẽ khớp ngay sau khi chạy.
-- TEST ONLY: không dùng cơ chế đăng nhập không xác minh này cho môi trường production.

-- Giữ migration tự chứa để dùng được cả với bộ cài hợp nhất.
create or replace function _is_demo_staff_phone_email(p_email text)
returns boolean
language sql immutable as $$
  select lower(btrim(coalesce(p_email, ''))) ~ '^p[0-9]{8,15}@phone[.]fore-staff[.]app$'
$$;

create or replace function _demo_staff_phone(
  p_phone text,
  p_phone_confirmed_at timestamptz,
  p_email text,
  p_metadata jsonb
) returns text
language sql immutable as $$
  select coalesce(
    normalize_phone(p_metadata ->> 'demo_phone'),
    case when p_phone_confirmed_at is not null then normalize_phone(p_phone) end,
    case when _is_demo_staff_phone_email(p_email)
      then substring(lower(btrim(p_email)) from '^p([0-9]+)@') end
  )
$$;

create or replace function _demo_staff_email(
  p_email text,
  p_email_confirmed_at timestamptz,
  p_metadata jsonb
) returns text
language sql immutable as $$
  select coalesce(
    nullif(lower(btrim(p_metadata ->> 'demo_email')), ''),
    case when p_email_confirmed_at is not null
           and not _is_demo_staff_phone_email(p_email)
      then lower(btrim(p_email)) end,
    case when p_email is not null and not _is_demo_staff_phone_email(p_email)
      then lower(btrim(p_email)) end
  )
$$;
revoke all on function _is_demo_staff_phone_email(text),
  _demo_staff_phone(text, timestamptz, text, jsonb),
  _demo_staff_email(text, timestamptz, jsonb)
  from public, anon, authenticated;

create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public, auth as $$
declare
  v_meta jsonb;
  v_raw_phone text;
  v_phone_confirmed_at timestamptz;
  v_raw_email text;
  v_email_confirmed_at timestamptz;
begin
  select u.raw_user_meta_data, u.phone::text, u.phone_confirmed_at,
         u.email::text, u.email_confirmed_at
    into v_meta, v_raw_phone, v_phone_confirmed_at,
         v_raw_email, v_email_confirmed_at
    from auth.users u
   where u.id = auth.uid();

  -- Metadata do app mới ghi được; các tài khoản cũ fallback về danh tính Auth.
  -- _auth_phone nhận diện email giả p<phone>@phone.fore-staff.app.
  phone := _demo_staff_phone(
    v_raw_phone, v_phone_confirmed_at, v_raw_email, v_meta);
  email := _demo_staff_email(v_raw_email, v_email_confirmed_at, v_meta);
end $$;
revoke all on function _my_verified_contacts() from public, anon, authenticated;

-- Ngăn mời lại thành viên đã đăng ký trước khi demo contact metadata được lưu.
create or replace function invite_staff(
  p_phone text,
  p_full_name text,
  p_email text default null
) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case
    when nullif(btrim(p_phone), '') is null then null
    else normalize_phone(p_phone)
  end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  if v_phone is null and v_email is null then
    raise exception 'CONTACT_REQUIRED';
  end if;
  if v_phone is not null and v_phone !~ '^[1-9][0-9]{7,14}$' then
    raise exception 'PHONE_INVALID';
  end if;
  if coalesce(btrim(p_full_name), '') = '' then
    raise exception 'NAME_REQUIRED';
  end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'EMAIL_INVALID';
  end if;

  if exists (
    select 1
      from staff s
      join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
       and s.active
       and (
         (v_phone is not null and _demo_staff_phone(
           u.phone::text, u.phone_confirmed_at, u.email::text,
           u.raw_user_meta_data) = v_phone)
         or
         (v_email is not null and _demo_staff_email(
           u.email::text, u.email_confirmed_at, u.raw_user_meta_data) = v_email)
       )
  ) then
    raise exception 'ALREADY_MEMBER';
  end if;

  begin
    insert into shop_invites(shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'ALREADY_INVITED';
  end;

  perform _audit('invite_staff', 'shop_invites', v_id,
    jsonb_build_object('phone', v_phone, 'email', v_email, 'name', btrim(p_full_name)));
  return v_id;
end $$;
revoke all on function invite_staff(text, text, text) from public, anon;
grant execute on function invite_staff(text, text, text) to authenticated;
