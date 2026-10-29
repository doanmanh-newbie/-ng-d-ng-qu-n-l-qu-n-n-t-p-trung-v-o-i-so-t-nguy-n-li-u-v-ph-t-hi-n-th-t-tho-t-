-- Fore · 016_audit_actor_same_shop.sql · Sửa nhật ký khi một người thuộc NHIỀU quán
-- Chạy sau 015_simple_staff_login.sql; không cần reset dữ liệu.
--
-- LỖI: `audit_log_actor_same_shop_fk` (001) bắt buộc (shop_id, actor) phải cùng một quán. Trigger
-- `audit_row_change` lấy shop_id từ DÒNG bị đổi nhưng actor từ `app_staff_id()` (nhân viên ở quán ĐANG CHỌN).
-- Nên người đã ở quán A mà tạo quán B (`create_shop`) hoặc chấp nhận lời mời vào quán B (`accept_invite`)
-- sẽ ghi (shop B, nhân viên của A) và bị khóa ngoại chặn: thao tác thất bại.
--
-- SỬA: actor là nhân viên của CHÍNH QUÁN CỦA DÒNG đó (nếu người này chưa là nhân viên ở đó thì để trống,
-- ví dụ lúc hệ thống tự gieo cấu hình cho quán vừa tạo).
create or replace function audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old jsonb; v_new jsonb; v_shop uuid; v_actor uuid;
begin
  if tg_op in ('UPDATE','DELETE') then v_old := to_jsonb(old) - 'pin_hash'; end if;
  if tg_op in ('INSERT','UPDATE') then v_new := to_jsonb(new) - 'pin_hash'; end if;
  v_shop := coalesce((v_new->>'shop_id')::uuid, (v_old->>'shop_id')::uuid, app_shop_id());
  select s.id into v_actor from staff s
   where s.auth_user_id = auth.uid() and s.shop_id = v_shop and s.active;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
  values (v_shop, v_actor, lower(tg_op), tg_table_name,
          coalesce(v_new->>'id', v_old->>'id')::uuid,
          jsonb_build_object('old', v_old, 'new', v_new));
  return coalesce(new, old);
end $$;
