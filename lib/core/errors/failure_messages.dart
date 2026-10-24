import 'app_failure.dart';

/// Chuyển lỗi thành câu tiếng Việt hiển thị cho người dùng.
extension FailureMessage on AppFailure {
  String get userMessage => switch (this) {
        NoNetworkFailure() => 'Không có mạng. Kiểm tra kết nối rồi thử lại.',
        InvalidCredentialsFailure() => 'Email hoặc mật khẩu chưa đúng.',
        EmailAlreadyRegisteredFailure() => 'Email này đã được đăng ký.',
        WeakPasswordFailure() => 'Mật khẩu cần ít nhất 8 ký tự.',
        EmailNotConfirmedFailure() =>
          'Email chưa được xác nhận. Kiểm tra hộp thư của bạn.',
        UnknownFailure() => 'Có lỗi xảy ra. Thử lại sau ít phút.',
      };
}
