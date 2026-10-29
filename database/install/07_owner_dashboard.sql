-- Fore canonical install module: 07_owner_dashboard.sql
-- Run modules in numeric order after database/dev/reset_schema.sql on a test project.

-- >>> Integrated source: database/012_owner_dashboard.sql
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
