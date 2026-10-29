-- Fore canonical install module: 05_membership_invites.sql
-- Run modules in numeric order after database/dev/reset_schema.sql on a test project.

-- >>> Integrated source: database/008_staff_setup.sql
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


-- >>> Integrated source: database/013_staff_birth_date.sql
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


-- >>> Integrated source: database/014_invite_phone_or_email.sql
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


-- >>> Integrated source: database/015_staff_demo_contacts.sql
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
