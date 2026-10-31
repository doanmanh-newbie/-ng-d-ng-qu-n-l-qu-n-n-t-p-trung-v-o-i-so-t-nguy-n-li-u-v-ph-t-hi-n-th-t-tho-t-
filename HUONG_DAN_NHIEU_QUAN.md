# Fore — bản nhiều quán (chủ / nhân viên)

## 1. Database (Supabase → SQL Editor)
Bản cũ chỉ có 1 quán nên **phải dựng lại** (dữ liệu nghiệp vụ sẽ mất; tài khoản Supabase Auth vẫn còn):
1. Chạy `database/00_reset_schema.sql` nếu bạn đã sao lưu hoặc chấp nhận xóa dữ liệu.
2. Chạy lần lượt `database/01_foundation.sql` → `02_operations_reconciliation.sql` → `03_read_apis.sql` → `04_membership_sessions.sql`.

Đây là bốn nhóm SQL hiện hành. Các bản trong `database/install/` và `database/dev/rebuild_test_database.sql` được sinh từ bốn nhóm này bằng `tool/build_install.sh`; không sửa trực tiếp các bản sinh.

Sau đó **không còn** hàm `claim_first_owner` / `link_staff_account`. Chủ quán tự tạo quán trong app; nhân viên được mời bằng số điện thoại.

## 2. Đăng nhập đơn giản để thử (Supabase → Authentication)
Hiện **không có mã xác nhận (OTP)**. Cần đúng một cài đặt: **Providers → Email → TẮT "Confirm email"**, để đăng ký xong vào được ngay.
Đừng bật Phone/SMS, không cần. Đăng nhập thử bằng điện thoại/email được cấu hình trong nhóm `04_membership_sessions.sql`.

## 3. Luồng sử dụng
- Màn đầu: **Chủ quán** hoặc **Nhân viên** (công tắc ngay trên form đăng nhập).
- Chủ: đăng ký email + mật khẩu → **Tạo quán** → Tab *Thêm* → *Nhân viên* → *Thêm nhân viên* (nhập số điện thoại hoặc email + tên).
- Nhân viên: bấm **Tạo tài khoản nhân viên**, chọn số điện thoại hoặc email, nhập tên và ngày sinh. Lần sau chỉ nhập số/email rồi bấm **Đăng nhập**.
  Chưa có quán thì vào không gian nhân viên có hộp thư; lời mời tự hiện (kéo xuống để làm mới). Bấm **Chấp nhận và vào quán** để tải dữ liệu quán.
- Một người thuộc nhiều quán: tab *Thêm* → bấm tên quán để đổi quán / tạo quán mới.

## 4. Bảo mật cần biết
Cách đăng nhập này **chỉ để thử**: mật khẩu nhân viên được app tự sinh từ chính số/email (xem `StaffCredentials`), nên ai biết số/email của người khác là vào được tài khoản của họ. Khi làm thật phải bật lại mã xác nhận (OTP) hoặc cho người dùng tự đặt mật khẩu, và bỏ `015` cùng `staff_credentials.dart`.
Mỗi quán có dữ liệu tách riêng (`shop_id` trên mọi bảng + RLS + các hàm đều lọc theo quán).

## 5. Việc bạn cần làm sau khi giải nén
`flutter pub get` → `dart format lib test` → `flutter analyze` → `flutter test`, rồi gửi mình lỗi nếu có (mình không chạy được Flutter trong môi trường này).
Xóa file cũ không còn dùng: `lib/features/auth/login_screen.dart` và `lib/features/auth/presentation/not_linked_screen.dart`.
