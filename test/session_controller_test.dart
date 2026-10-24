import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;

  SessionController build({Duration? timeout}) => SessionController(
        repo,
        minVisible: const Duration(milliseconds: 20),
        timeout: timeout ?? const Duration(seconds: 1),
      );

  setUp(() => repo = FakeAuthRepository());

  const profile = Profile(
    staffId: 's1',
    fullName: 'Nguyễn An',
    role: StaffRole.staff,
    hasPin: false,
    active: true,
  );

  test('chưa đăng nhập -> SessionSignedOut', () async {
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionSignedOut>());
  });

  test('đã đăng nhập và có hồ sơ -> SessionSignedIn', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.profile = profile;
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionSignedIn>());
  });

  test('đăng nhập được nhưng chưa có hồ sơ -> SessionNotLinked', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    final c = build();
    await c.restore();
    final state = c.state;
    expect(state, isA<SessionNotLinked>());
    expect((state as SessionNotLinked).email, 'an@quan.vn');
  });

  test('hồ sơ đã bị tắt (active=false) cũng coi là chưa được thêm', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.profile = const Profile(
      staffId: 's1',
      fullName: 'An',
      role: StaffRole.staff,
      hasPin: false,
      active: false,
    );
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionNotLinked>());
  });

  test('mất mạng -> SessionOffline, thử lại được', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.failure = const NoNetworkFailure();
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionOffline>());

    repo.failure = null;
    repo.profile = profile;
    await c.restore();
    expect(c.state, isA<SessionSignedIn>());
  });

  test('quá thời gian chờ -> SessionOffline', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.delay = const Duration(milliseconds: 300);
    final c = build(timeout: const Duration(milliseconds: 50));
    await c.restore();
    expect(c.state, isA<SessionOffline>());
  });

  test('splash hiện tối thiểu minVisible dù kiểm tra xong sớm', () async {
    final c = build();
    final watch = Stopwatch()..start();
    await c.restore();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(18));
  });

  test('signOut đưa về SessionSignedOut', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.profile = profile;
    final c = build();
    await c.restore();
    await c.signOut();
    expect(c.state, isA<SessionSignedOut>());
    expect(repo.signOutCalls, 1);
  });
}
