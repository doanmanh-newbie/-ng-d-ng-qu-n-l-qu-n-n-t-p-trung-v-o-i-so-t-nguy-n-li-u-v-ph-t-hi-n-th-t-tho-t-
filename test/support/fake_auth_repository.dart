import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';
import 'package:fore/features/auth/domain/staff_contact.dart';

/// Bản giả của [AuthRepository] cho test: không cần mạng, không cần Supabase.
/// Đặt `failure` để mô phỏng lỗi ở mọi lệnh gọi.
class FakeAuthRepository implements AuthRepository {
  AuthUser? user;
  Profile? profile;
  AppFailure? failure;

  /// Lỗi riêng cho đăng xuất (ví dụ mất mạng lúc đăng xuất).
  AppFailure? signOutFailure;
  Duration delay = Duration.zero;

  final registered = <String>{};
  int signUpCalls = 0;
  int signOutCalls = 0;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (!registered.contains(email) || password != 'matkhau123') {
      throw const InvalidCredentialsFailure();
    }
    return user = AuthUser(id: 'u1', email: email);
  }

  @override
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (registered.contains(email)) throw const EmailAlreadyRegisteredFailure();
    registered.add(email);
    return false;
  }

  /// Tài khoản nhân viên đã tạo, theo `StaffContact.value`.
  final staffAccounts = <String>{};
  int signUpStaffCalls = 0;

  @override
  Future<AuthUser> signInStaff(StaffContact contact) async {
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (!staffAccounts.contains(contact.value)) {
      throw const StaffNotFoundFailure();
    }
    return user = AuthUser(
      id: 'staff-${contact.value}',
      email: contact.email ?? '',
      phone: contact.phone?.substring(1) ?? '',
    );
  }

  @override
  Future<AuthUser> signUpStaff({
    required StaffContact contact,
    required String fullName,
    required DateTime birthDate,
  }) async {
    signUpStaffCalls++;
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (!staffAccounts.add(contact.value)) {
      throw const StaffAlreadyExistsFailure();
    }
    return user = AuthUser(
      id: 'staff-${contact.value}',
      email: contact.email ?? '',
      phone: contact.phone?.substring(1) ?? '',
      displayName: fullName,
      birthDate: birthDate.toIso8601String().substring(0, 10),
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutFailure != null) throw signOutFailure!;
    user = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<Profile?> fetchProfile() async {
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return profile;
  }
}
