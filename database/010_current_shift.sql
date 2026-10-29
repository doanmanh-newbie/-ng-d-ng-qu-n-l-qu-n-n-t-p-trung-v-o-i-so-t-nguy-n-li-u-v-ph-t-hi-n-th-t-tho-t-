-- =====================================================================
-- Fore · 010_current_shift.sql · Xem ca đang mở (cho MỌI nhân viên)
-- Cả quán chỉ có tối đa 1 ca mở. Người đến sau cần biết "ca đang mở, ai mở, lúc nào,
-- có phải mình mở không, còn mấy bill đang mở" để bấm "Vào ca" thay vì "Mở ca".
-- Nhân viên không đọc được bảng staff nên cần hàm này. Hàm KHÔNG trả số tiền đầu ca
-- và không trả doanh thu (nhân viên không cần thấy).
-- Chạy SAU 009. Gọi từ app: supabase.rpc('current_shift'). Không có ca mở thì trả 0 dòng.
-- Chạy lại nhiều lần được (drop trước khi tạo, vì đổi số cột trả về).
-- =====================================================================

drop function if exists current_shift();

create function current_shift()
returns table (
  shift_id        uuid,
  opened_by_name  text,
  opened_at       timestamptz,   -- giờ máy chủ
  opened_by_me    boolean,       -- người gọi chính là người mở ca
  open_bills      integer        -- số bill đang mở trong ca (trước khi đóng ca phải xử lý hết)
)
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff();   -- NOT_STAFF nếu không phải nhân viên đang hoạt động
begin
  return query
    select s.id,
           st.full_name,
           s.opened_at,
           s.opened_by = v_me,
           (select count(*)::integer from bills b where b.shift_id = s.id and b.status = 'open')
      from shifts s
      join staff st on st.id = s.opened_by
     where s.status = 'open' and s.shop_id = app_shop_id();
end $$;

revoke all on function current_shift() from public, anon;
grant execute on function current_shift() to authenticated;
