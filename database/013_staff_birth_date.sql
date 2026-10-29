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
