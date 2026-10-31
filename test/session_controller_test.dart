import 'package:flutter_test/flutter_test.dart';
import 'package:fore/app/app_routes.dart';
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
    shopId: 'shop-1',
    shopName: 'Quán A',
  );

  test('chưa đăng nhập -> SignedOut', () async {
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionSignedOut>());
  });

  test('đăng nhập và có membership đang hoạt động -> Ready', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.profile = profile;
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionReady>());
    expect((c.state as SessionReady).profile.shopId, 'shop-1');
    expect(repo.rememberedShopId, 'shop-1');
  });

  test('nhân viên chưa có quán -> chờ lời mời và giữ contact', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    final c = build();
    await c.restore();
    final state = c.state as SessionAwaitingInvite;
    expect(state.user.contact, 'an@quan.vn');
    expect(AppRoutes.routeFor(state), AppRoutes.emptySpace);
  });

  test('chủ chưa tạo quán -> NeedsShop ngay cả khi khôi phục phiên', () async {
    repo.user = const AuthUser(
        id: 'u-owner', email: 'chu@quan.vn', accountKind: AccountKind.owner);
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionNeedsShop>());
    expect(AppRoutes.routeFor(c.state), AppRoutes.createShop);
  });

  test('role của membership thắng account kind khi một người nhiều vai trò',
      () async {
    repo.user = const AuthUser(
        id: 'u-mixed', email: 'mixed@quan.vn', accountKind: AccountKind.staff);
    repo.profile = const Profile(
      staffId: 'owner-a',
      fullName: 'Chủ ở A',
      role: StaffRole.owner,
      hasPin: true,
      active: true,
      shopId: 'shop-a',
      shopName: 'Quán A',
    );
    final c = build();
    await c.restore();
    expect((c.state as SessionReady).profile.role, StaffRole.owner);
  });

  test('tài khoản nhân viên qua số điện thoại hiện đúng contact', () async {
    repo.user = const AuthUser(
        id: 'u1', phone: '84901234567', accountKind: AccountKind.staff);
    final c = build();
    await c.restore();
    expect((c.state as SessionAwaitingInvite).user.contact, '+84901234567');
  });

  test('membership cũ đã bị thu hồi -> trạng thái rõ ràng kèm route riêng',
      () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.rememberedShopId = 'shop-removed';
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionMembershipRevoked>());
    expect(AppRoutes.routeFor(c.state), AppRoutes.membershipRevoked);
  });

  test('membership inactive không tạo Ready', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.profile = const Profile(
      staffId: 's1',
      fullName: 'An',
      role: StaffRole.staff,
      hasPin: false,
      active: false,
    );
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionAwaitingInvite>());
  });

  test('mất mạng -> Offline, thử lại có thể vào Ready', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.failure = const NoNetworkFailure();
    final c = build();
    await c.restore();
    expect(c.state, isA<SessionOffline>());
    repo.failure = null;
    repo.profile = profile;
    await c.restore();
    expect(c.state, isA<SessionReady>());
  });

  test('quá thời gian chờ -> Offline', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.delay = const Duration(milliseconds: 300);
    final c = build(timeout: const Duration(milliseconds: 50));
    await c.restore();
    expect(c.state, isA<SessionOffline>());
  });

  test('splash hiện tối thiểu minVisible', () async {
    final watch = Stopwatch()..start();
    await build().restore();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(18));
  });

  test('sign out -> SignedOut', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.profile = profile;
    final c = build();
    await c.restore();
    expect(await c.signOut(), isNull);
    expect(c.state, isA<SessionSignedOut>());
    expect(repo.signOutCalls, 1);
  });

  test('refresh trả lỗi mạng và giữ trạng thái cũ', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    final c = build();
    await c.restore();
    repo.failure = const NoNetworkFailure();
    expect(await c.refreshAfterSignIn(), isA<NoNetworkFailure>());
    expect(c.state, isA<SessionAwaitingInvite>());
  });

  test('refresh trả lỗi lạ thay vì ném ra ngoài', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.failure = const UnknownFailure('hỏng');
    expect(await build().refreshAfterSignIn(), isA<UnknownFailure>());
  });

  test('chọn quán gọi repository và làm mới membership từ server', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.profile = profile;
    final c = build();
    expect(await c.chooseShop('shop-1'), isNull);
    expect(repo.rememberedShopId, 'shop-1');
    expect((c.state as SessionReady).profile.shopId, 'shop-1');
  });

  test('sign out lỗi giữ nguyên trạng thái', () async {
    repo.user = const AuthUser(
        id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff);
    repo.profile = profile;
    final c = build();
    await c.restore();
    repo.signOutFailure = const NoNetworkFailure();
    expect(await c.signOut(), isA<NoNetworkFailure>());
    expect(c.state, isA<SessionReady>());
  });
}
