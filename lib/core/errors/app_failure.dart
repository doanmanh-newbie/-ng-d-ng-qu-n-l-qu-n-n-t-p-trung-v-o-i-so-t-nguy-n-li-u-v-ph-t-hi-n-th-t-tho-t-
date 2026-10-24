/// Mọi lỗi nghiệp vụ của app là một lớp con của [AppFailure].
///
/// - `code` là mã lỗi viết hoa tiếng Anh (khớp quy ước với database).
/// - Câu tiếng Việt cho người dùng nằm ở `failure_messages.dart`,
///   để lớp lỗi không phụ thuộc vào giao diện.
///
/// `sealed` giúp `switch` bắt buộc xử lý đủ mọi loại lỗi: thêm lỗi mới mà
/// quên viết câu thông báo thì trình biên dịch báo ngay.
sealed class AppFailure implements Exception {
  const AppFailure(this.code);

  final String code;

  @override
  String toString() => '$runtimeType($code)';
}

class NoNetworkFailure extends AppFailure {
  const NoNetworkFailure() : super('NO_NETWORK');
}

class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure() : super('INVALID_CREDENTIALS');
}

class EmailAlreadyRegisteredFailure extends AppFailure {
  const EmailAlreadyRegisteredFailure() : super('EMAIL_ALREADY_REGISTERED');
}

class WeakPasswordFailure extends AppFailure {
  const WeakPasswordFailure() : super('WEAK_PASSWORD');
}

class EmailNotConfirmedFailure extends AppFailure {
  const EmailNotConfirmedFailure() : super('EMAIL_NOT_CONFIRMED');
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([this.detail]) : super('UNKNOWN');

  /// Chi tiết kỹ thuật để ghi log, không hiện cho người dùng.
  final Object? detail;
}
