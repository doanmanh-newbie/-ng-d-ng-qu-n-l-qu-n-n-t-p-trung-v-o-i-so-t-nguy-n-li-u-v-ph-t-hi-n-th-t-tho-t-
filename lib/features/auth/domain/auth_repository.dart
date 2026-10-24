import 'auth_models.dart';

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

  /// Tạo tài khoản. Không vào được quán ngay: chủ quán phải thêm email này.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Hồ sơ trong quán của người đang đăng nhập; `null` nếu chưa được thêm.
  Future<Profile?> fetchProfile();
}
