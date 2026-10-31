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
