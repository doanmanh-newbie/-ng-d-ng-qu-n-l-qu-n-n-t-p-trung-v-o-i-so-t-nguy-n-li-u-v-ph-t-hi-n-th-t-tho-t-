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
