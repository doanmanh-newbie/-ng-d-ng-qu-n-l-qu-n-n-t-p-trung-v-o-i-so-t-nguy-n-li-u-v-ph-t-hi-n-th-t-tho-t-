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

  test('đăng nhập được nhưng chưa có hồ sơ -> SessionNoShop', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    final c = build();
    await c.restore();
    final state = c.state;
    expect(state, isA<SessionNoShop>());
    expect((state as SessionNoShop).contact, 'an@quan.vn');
  });

  test('hồ sơ đã bị tắt (active=false) cũng coi là chưa thuộc quán', () async {
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
    final state = c.state;
    expect(state, isA<SessionNoShop>());
  });

  test('đăng nhập bằng số điện thoại: contact là số có dấu +', () async {
    repo.user = const AuthUser(id: 'u1', phone: '84901234567');
    final c = build();
    await c.restore();
    expect((c.state as SessionNoShop).contact, '+84901234567');
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
    expect(await c.signOut(), isNull);
    expect(c.state, isA<SessionSignedOut>());
    expect(repo.signOutCalls, 1);
  });

  group('refreshAfterSignIn', () {
    test('thành công -> null và cập nhật trạng thái', () async {
      repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
      repo.profile = profile;
      final c = build();
      final failure = await c.refreshAfterSignIn();
      expect(failure, isNull);
      expect(c.state, isA<SessionSignedIn>());
    });

    test('mất mạng -> trả lỗi, giữ nguyên trạng thái cũ', () async {
      repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
      final c = build();
      await c.restore();
      expect(c.state, isA<SessionNoShop>());

      repo.failure = const NoNetworkFailure();
      final failure = await c.refreshAfterSignIn();
      expect(failure, isA<NoNetworkFailure>());
      expect(c.state, isA<SessionNoShop>());
    });

    test('lỗi lạ cũng được trả về, không văng ra ngoài', () async {
      repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
      repo.failure = UnknownFailure('hỏng');
      final c = build();
      final failure = await c.refreshAfterSignIn();
      expect(failure, isA<UnknownFailure>());
    });
  });

  test('signOut lỗi (mất mạng) -> trả lỗi, vẫn ở trạng thái cũ', () async {
    repo.user = const AuthUser(id: 'u1', email: 'an@quan.vn');
    repo.profile = profile;
    final c = build();
    await c.restore();
    repo.signOutFailure = const NoNetworkFailure();
    final failure = await c.signOut();
    expect(failure, isA<NoNetworkFailure>());
    expect(c.state, isA<SessionSignedIn>());
  });
}
