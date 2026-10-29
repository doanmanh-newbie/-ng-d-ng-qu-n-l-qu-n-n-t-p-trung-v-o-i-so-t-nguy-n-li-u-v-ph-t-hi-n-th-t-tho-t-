import 'auth_models.dart';
import 'staff_contact.dart';

/// Hợp đồng truy cập tài khoản. Controller và màn hình chỉ biết lớp này,
/// không biết Supabase. Nhờ vậy:
///  - test dùng được bản giả (không cần mạng),
///  - đổi nhà cung cấp chỉ phải viết lại một lớp ở thư mục `data/`.
///
/// Mọi lỗi được ném ra là một [AppFailure].
abstract interface class AuthRepository {
  /// Người đang đăng nhập (đọc từ bộ nhớ máy, không cần mạng). `null` nếu chưa.
  AuthUser? get currentUser;

  Future<AuthUser> signIn({required String email, required String password});

  /// Tạo tài khoản chủ quán (email + mật khẩu). Trả về `true` nếu đã đăng nhập luôn
  /// (Supabase tắt xác nhận email), `false` nếu phải xác nhận email rồi mới đăng nhập.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  /// Đăng nhập nhân viên chỉ bằng số điện thoại hoặc email (xem `StaffCredentials`).
  /// Chưa có tài khoản thì ném `StaffNotFoundFailure`.
  Future<AuthUser> signInStaff(StaffContact contact);

  /// Tạo tài khoản nhân viên và đăng nhập luôn. Tên và ngày sinh được lưu vào tài khoản
  /// và chép sang hồ sơ trong quán khi nhân viên chấp nhận lời mời.
  /// Đã có tài khoản thì ném `StaffAlreadyExistsFailure`.
  Future<AuthUser> signUpStaff({
    required StaffContact contact,
    required String fullName,
    required DateTime birthDate,
  });

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Hồ sơ trong quán của người đang đăng nhập; `null` nếu chưa được thêm.
  Future<Profile?> fetchProfile();
}
