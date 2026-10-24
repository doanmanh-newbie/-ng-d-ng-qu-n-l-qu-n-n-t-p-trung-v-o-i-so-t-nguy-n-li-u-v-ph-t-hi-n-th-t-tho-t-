import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';

/// Bản giả của [AuthRepository] cho test: không cần mạng, không cần Supabase.
/// Đặt `failure` để mô phỏng lỗi ở mọi lệnh gọi.
class FakeAuthRepository implements AuthRepository {
  AuthUser? user;
  Profile? profile;
  AppFailure? failure;
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
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (registered.contains(email)) throw const EmailAlreadyRegisteredFailure();
    registered.add(email);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
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
