import 'staff_contact.dart';

/// ĐĂNG NHẬP ĐƠN GIẢN CHO NHÂN VIÊN (chỉ để thử, KHÔNG dùng khi chạy thật).
///
/// Nhân viên chỉ nhập số điện thoại HOẶC email, không gõ mật khẩu và không có mã xác nhận (OTP).
/// Supabase Auth thì cần một email và một mật khẩu, nên app tự sinh cả hai từ chính số/email đó:
/// - Email: dùng luôn email người dùng nhập. Với số điện thoại thì dùng một email giả
///   `p84901234567@phone.fore-staff.app` (không cần nhà cung cấp SMS). Database nhận ra dạng
///   này và coi nó là số điện thoại, xem `database/015_simple_staff_login.sql`.
/// - Mật khẩu: ghép từ một tiền tố cố định và chính số/email.
///
/// Hậu quả: ai biết số/email của người khác là vào được tài khoản của họ. Khi làm đăng nhập thật,
/// xóa file này và dùng mã xác nhận (OTP) hoặc mật khẩu do người dùng tự đặt.
abstract final class StaffCredentials {
  /// Tên miền của email giả. PHẢI trùng `_phone_login_domain()` trong `015_simple_staff_login.sql`.
  /// Nếu Supabase từ chối tên miền này ("email address is invalid"), đổi ở cả hai nơi.
  static const phoneEmailDomain = 'phone.fore-staff.app';

  // Có đủ chữ hoa, chữ thường, số và ký hiệu để qua được mọi cấu hình độ mạnh mật khẩu.
  static const _prefix = 'Fore#Staff2026-';

  static final _phoneEmailPattern =
      RegExp('^p([0-9]{8,15})@${RegExp.escape(phoneEmailDomain)}\$');

  /// Email dùng để đăng nhập Supabase.
  static String emailFor(StaffContact contact) =>
      contact.kind == ContactKind.email
          ? contact.value
          : 'p${contact.value.substring(1)}@$phoneEmailDomain'; // bỏ dấu "+"

  static String passwordFor(StaffContact contact) => '$_prefix${contact.value}';

  /// Số điện thoại (dạng `84901234567`, không có "+") nếu `email` là email giả của số điện
  /// thoại; ngược lại `null`.
  static String? phoneFromEmail(String email) =>
      _phoneEmailPattern.firstMatch(email.trim().toLowerCase())?.group(1);
}
