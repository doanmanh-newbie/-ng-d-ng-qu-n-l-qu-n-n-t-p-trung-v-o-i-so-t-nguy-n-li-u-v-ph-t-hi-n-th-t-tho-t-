import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Cài đặt [AuthRepository] bằng Supabase. Là nơi duy nhất trong tính năng
/// đăng nhập biết về Supabase và đổi lỗi của nó thành [AppFailure].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _client.auth
            .signInWithPassword(email: email, password: password);
        final user = res.user;
        if (user == null) throw const InvalidCredentialsFailure();
        return _toAuthUser(user);
      });

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName},
        );
        // Khi bật xác nhận email, Supabase không báo lỗi nếu email đã tồn tại
        // mà trả về user không có `identities`.
        if (res.user?.identities?.isEmpty ?? false) {
          throw const EmailAlreadyRegisteredFailure();
        }
        // Khi tắt xác nhận email, đăng ký xong là đăng nhập luôn.
        // Đăng xuất để người dùng đi đúng luồng: chờ chủ quán thêm vào quán.
        if (res.session != null) await _client.auth.signOut();
      });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email));

  @override
  Future<Profile?> fetchProfile() => _guard(() async {
        final rows = await _client.rpc('my_profile') as List<dynamic>;
        if (rows.isEmpty) return null;
        return Profile.fromMap(rows.first as Map<String, dynamic>);
      });

  AuthUser _toAuthUser(User user) =>
      AuthUser(id: user.id, email: user.email ?? '');

  /// Bọc mọi lệnh gọi: lỗi của Supabase/mạng đổi thành [AppFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const NoNetworkFailure();
    } on AuthWeakPasswordException {
      throw const WeakPasswordFailure();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } on SocketException {
      throw const NoNetworkFailure();
    } on TimeoutException {
      throw const NoNetworkFailure();
    } catch (e) {
      throw UnknownFailure(e);
    }
  }

  AppFailure _mapAuthException(AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const InvalidCredentialsFailure();
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return const EmailAlreadyRegisteredFailure();
    }
    if (code == 'weak_password') return const WeakPasswordFailure();
    if (code == 'email_not_confirmed') return const EmailNotConfirmedFailure();
    return UnknownFailure(e);
  }
}
