-- =====================================================================
-- Fore · 008_staff_setup.sql · Tạo và nối tài khoản nhân sự
-- Quy trình:
--   1) Chủ đăng ký tài khoản (email/mật khẩu) qua Supabase Auth, đăng nhập, gọi claim_first_owner(tên).
--      Chỉ chạy được khi CHƯA có chủ nào. Sau đó TẮT đăng ký công khai trong Supabase (Auth settings).
--   2) Nhân viên đăng ký tài khoản; chủ gọi link_staff_account(email, tên, 'staff') để nối vào bảng staff.
--   3) Chủ đặt PIN bằng set_staff_pin. Nghỉ việc: đặt active = false (không xóa).
-- Chạy SAU 007_corrections.sql.
-- =====================================================================

-- Không cho khóa hoặc hạ quyền của chủ cuối cùng (tránh tự khóa mình ra khỏi hệ thống)
create or replace function staff_guard() returns trigger
language plpgsql as $$
begin
  if old.role = 'owner' and old.active and (new.active = false or new.role <> 'owner') then
    if not exists (select 1 from staff s where s.role = 'owner' and s.active and s.id <> old.id) then
      raise exception 'LAST_OWNER' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger staff_guard_trg before update on staff for each row execute function staff_guard();

-- Người đăng nhập đầu tiên trở thành chủ (chỉ khi chưa có chủ)
create or replace function claim_first_owner(p_full_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtext('fore_claim_first_owner'));   -- 2 người bấm cùng lúc: chỉ 1 người thắng
  if exists (select 1 from staff where role = 'owner') then raise exception 'OWNER_EXISTS'; end if;
  if exists (select 1 from staff where auth_user_id = v_uid) then raise exception 'ALREADY_STAFF'; end if;
  insert into staff (auth_user_id, full_name, role) values (v_uid, btrim(p_full_name), 'owner') returning id into v_id;
  return v_id;
end $$;

-- Chủ nối một tài khoản đã đăng ký (theo email) vào bảng nhân sự
create or replace function link_staff_account(p_email text, p_full_name text, p_role text default 'staff') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid; v_id uuid;
begin
  perform _require_owner();
  if p_role not in ('owner', 'staff') then raise exception 'ROLE_INVALID'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  select u.id into v_uid from auth.users u where lower(u.email) = lower(btrim(p_email));
  if v_uid is null then raise exception 'USER_NOT_FOUND'; end if;      -- người đó chưa đăng ký tài khoản
  if exists (select 1 from staff where auth_user_id = v_uid) then raise exception 'ALREADY_STAFF'; end if;
  insert into staff (auth_user_id, full_name, role) values (v_uid, btrim(p_full_name), p_role) returning id into v_id;
  return v_id;
end $$;

-- Thông tin của chính người đang đăng nhập (không có cột PIN)
create or replace function my_profile()
returns table (staff_id uuid, full_name text, role text, has_pin boolean, active boolean)
language sql stable security definer set search_path = public as $$
  select s.id, s.full_name, s.role, s.pin_hash is not null, s.active
    from staff s where s.auth_user_id = auth.uid()
$$;

revoke all on function claim_first_owner(text), link_staff_account(text, text, text), my_profile() from public, anon;
grant execute on function claim_first_owner(text), link_staff_account(text, text, text), my_profile() to authenticated;
