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
  v_n           int := greatest(_setting('streak_shifts', 3), 2);
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
  if not (app_is_owner() or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;
  select opened_at into v_opened from shifts where id = p_shift;
  if v_opened is null then raise exception 'NOT_FOUND'; end if;

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
    select id from shifts where status = 'closed' and opened_at < v_opened
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
  select count(*) into v_missing from v_items_without_recipe;

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
