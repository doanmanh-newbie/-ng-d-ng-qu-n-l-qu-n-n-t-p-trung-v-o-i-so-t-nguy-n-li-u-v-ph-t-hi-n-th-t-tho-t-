-- Fore · 015_simple_staff_login.sql · ĐĂNG NHẬP NHÂN VIÊN ĐƠN GIẢN (CHỈ ĐỂ THỬ)
-- Chạy sau 014_invite_phone_or_email.sql; không cần reset dữ liệu.
--
-- Nhân viên chỉ nhập số điện thoại HOẶC email, không có mã xác nhận (OTP) và không phải gõ mật khẩu.
-- App tự sinh mật khẩu từ chính số/email đó (xem `StaffCredentials` trong Flutter).
--
-- Supabase chỉ cho đăng ký bằng số điện thoại khi đã cấu hình nhà cung cấp SMS. Để khỏi cần SMS,
-- app đăng ký số điện thoại bằng một EMAIL GIẢ có dạng  p84901234567@phone.fore-staff.app
-- (chữ "p" + số quốc tế không dấu "+"). Database nhận ra dạng này và coi nó là SỐ ĐIỆN THOẠI,
-- nên lời mời gửi bằng số điện thoại vẫn tới đúng người.
--
-- Cài đặt Supabase cần có: Authentication -> Providers -> Email -> TẮT "Confirm email".
--
-- Khi làm đăng nhập thật (OTP) sau này: bỏ file này, dùng lại số điện thoại/email đã xác thực
-- như `_my_verified_contacts` trong 008 và `StaffCredentials` bị xóa khỏi app.
-- =====================================================================

-- Tên miền của email giả. PHẢI trùng `StaffCredentials.phoneEmailDomain` trong Flutter.
create or replace function _phone_login_domain() returns text
language sql immutable as $$ select 'phone.fore-staff.app'::text $$;

-- Email này có phải email giả đại diện cho số điện thoại không?
create or replace function _is_phone_login(p_email text) returns boolean
language sql immutable as $$
  select lower(btrim(coalesce(p_email, ''))) ~ ('^p[0-9]{8,15}@' || replace(_phone_login_domain(), '.', '\.') || '$')
$$;

-- Số điện thoại của một tài khoản (dạng 84901234567): số đã xác thực của Supabase,
-- hoặc số nằm trong email giả. `null` nếu tài khoản không có số.
create or replace function _auth_phone(p_phone text, p_phone_confirmed_at timestamptz, p_email text) returns text
language sql immutable as $$
  select coalesce(
    case when p_phone_confirmed_at is not null then normalize_phone(p_phone) end,
    case when _is_phone_login(p_email)
         then substring(lower(btrim(p_email)) from '^p([0-9]+)@') end)
$$;

-- Email thật của một tài khoản (đã xác nhận, không tính email giả). `null` nếu không có.
create or replace function _auth_email(p_email text, p_email_confirmed_at timestamptz) returns text
language sql immutable as $$
  select case when p_email_confirmed_at is not null and not _is_phone_login(p_email)
              then lower(btrim(p_email)) end
$$;

revoke all on function _phone_login_domain(), _is_phone_login(text), _auth_phone(text, timestamptz, text),
  _auth_email(text, timestamptz) from public, anon, authenticated;

-- Liên hệ của người đang đăng nhập, dùng để tìm lời mời gửi cho họ.
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public as $$
begin
  select _auth_phone(u.phone, u.phone_confirmed_at, u.email),
         _auth_email(u.email, u.email_confirmed_at)
    into phone, email
    from auth.users u where u.id = auth.uid();
end $$;

-- Mời nhân viên: nhận ra người đã là thành viên dù họ đăng ký bằng số điện thoại, email thật hay email giả.
create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case when nullif(btrim(p_phone), '') is null then null else normalize_phone(p_phone) end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  -- Có nhập số mà không đọc được thì báo sai số, không được lặng lẽ bỏ qua rồi chỉ mời bằng email.
  if nullif(btrim(p_phone), '') is not null and (v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$') then
    raise exception 'PHONE_INVALID';
  end if;
  if v_phone is null and v_email is null then raise exception 'CONTACT_REQUIRED'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if exists (
    select 1 from staff s join auth.users u on u.id = s.auth_user_id
    where s.shop_id = app_shop_id() and s.active and (
      (v_phone is not null and _auth_phone(u.phone, u.phone_confirmed_at, u.email) = v_phone)
      or (v_email is not null and _auth_email(u.email, u.email_confirmed_at) = v_email)))
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

-- Danh sách nhân viên cho chủ: số điện thoại lấy từ email giả, không hiện email giả ra màn hình.
create or replace function shop_team()
returns table (staff_id uuid, full_name text, role text, active boolean, phone text, email text, has_pin boolean, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return query
    select s.id, s.full_name, s.role, s.active,
           _auth_phone(u.phone, u.phone_confirmed_at, u.email),
           case when _is_phone_login(u.email) then null else u.email::text end,
           s.pin_hash is not null, s.created_at
      from staff s left join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
     order by (s.role = 'owner') desc, s.active desc, s.created_at;
end $$;

revoke all on function invite_staff(text, text, text), shop_team() from public, anon;
grant execute on function invite_staff(text, text, text), shop_team() to authenticated;
