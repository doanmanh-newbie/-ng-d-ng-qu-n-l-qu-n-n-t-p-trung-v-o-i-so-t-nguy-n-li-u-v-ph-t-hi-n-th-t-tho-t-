import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Đăng nhập nhân viên chỉ bằng số điện thoại HOẶC email (không mật khẩu, không mã xác nhận).
/// Xem `StaffCredentials` để biết cách làm và vì sao chỉ dùng được khi thử.
class StaffLoginController extends ChangeNotifier {
  StaffLoginController(this._repository);

  final AuthRepository _repository;

  ContactKind _kind = ContactKind.phone;
  ContactKind get kind => _kind;

  bool _loading = false;
  bool get loading => _loading;

  /// Lỗi của ô nhập số/email.
  String? contactError;

  /// Lỗi chung không gắn với ô nào (mất mạng, lỗi lạ).
  String? formError;

  void setKind(ContactKind kind) {
    if (_loading || kind == _kind) return;
    _kind = kind;
    contactError = formError = null;
    notifyListeners();
  }

  /// Đăng nhập. Trả về `true` nếu đã đăng nhập và có thể vào app.
  Future<bool> submit(String raw) async {
    contactError = formError = null;
    final parsed = StaffContact.tryParse(_kind, raw);
    final contact = parsed.contact;
    if (contact == null) {
      contactError = parsed.error;
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.signInStaff(contact);
      _loading = false;
      notifyListeners();
      return true;
    } on StaffNotFoundFailure catch (f) {
      contactError = f.userMessage;
    } on AppFailure catch (f) {
      formError = f.userMessage;
    }
    _loading = false;
    notifyListeners();
    return false;
  }
}
