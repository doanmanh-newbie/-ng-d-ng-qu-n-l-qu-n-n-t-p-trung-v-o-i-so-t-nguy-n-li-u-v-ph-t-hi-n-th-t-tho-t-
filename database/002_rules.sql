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
