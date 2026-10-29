import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Tạo tài khoản nhân viên: số điện thoại HOẶC email, tên hiển thị, ngày sinh.
class StaffRegisterController extends ChangeNotifier {
  StaffRegisterController(this._repository);

  final AuthRepository _repository;

  ContactKind _kind = ContactKind.phone;
  ContactKind get kind => _kind;

  bool _loading = false;
  bool get loading => _loading;

  String? contactError;
  String? nameError;
  String? birthDateError;

  /// Lỗi chung không gắn với ô nào (mất mạng, lỗi lạ).
  String? formError;

  void setKind(ContactKind kind) {
    if (_loading || kind == _kind) return;
    _kind = kind;
    contactError = formError = null;
    notifyListeners();
  }

  /// Người dùng bắt đầu sửa một ô: xóa lỗi cũ của ô đó (không để dòng đỏ nằm lại khi đã nhập đúng).
  void clearContactError() {
    if (contactError == null && formError == null) return;
    contactError = formError = null;
    notifyListeners();
  }

  void clearNameError() {
    if (nameError == null) return;
    nameError = null;
    notifyListeners();
  }

  void clearBirthDateError() {
    if (birthDateError == null) return;
    birthDateError = null;
    notifyListeners();
  }

  /// Tạo tài khoản. Trả về `true` nếu đã tạo xong và đăng nhập luôn.
  Future<bool> submit({
    required String contactText,
    required String fullName,
    required DateTime? birthDate,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final parsed = StaffContact.tryParse(_kind, contactText);
    final contact = parsed.contact;
    final name = fullName.trim();

    contactError = parsed.error;
    nameError = name.isEmpty ? 'Nhập tên hiển thị.' : null;
    birthDateError = birthDate == null
        ? 'Chọn ngày sinh.'
        : birthDate.isAfter(today)
            ? 'Ngày sinh không được ở tương lai.'
            : null;
    formError = null;

    if (contact == null || nameError != null || birthDateError != null) {
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.signUpStaff(
        contact: contact,
        fullName: name,
        birthDate: birthDate!,
      );
      _loading = false;
      notifyListeners();
      return true;
    } on StaffAlreadyExistsFailure catch (f) {
      contactError = f.userMessage;
    } on AppFailure catch (f) {
      formError = f.userMessage;
    }
    _loading = false;
    notifyListeners();
    return false;
  }
}
