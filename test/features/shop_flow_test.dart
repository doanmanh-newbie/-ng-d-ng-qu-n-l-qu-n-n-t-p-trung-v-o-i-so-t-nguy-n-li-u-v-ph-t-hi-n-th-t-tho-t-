import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shop/application/inbox_controller.dart';
import 'package:fore/features/shop/application/team_controller.dart';
import 'package:fore/features/shop/domain/shop_models.dart';

import '../support/fake_shop_repository.dart';

void main() {
  late FakeShopRepository repository;

  setUp(() => repository = FakeShopRepository());

  test('chủ tạo quán, tạo lỗi quyền được giữ lại cho UI xử lý', () async {
    await repository.createShop(shopName: 'Quán An', ownerName: 'An');
    expect(repository.createdShopName, 'Quán An');
    expect(repository.createdOwnerName, 'An');

    repository.failure = const OwnerOnlyFailure();
    await expectLater(
      repository.createShop(shopName: 'Quán khác', ownerName: 'An'),
      throwsA(isA<OwnerOnlyFailure>()),
    );
    expect(repository.createdShopName, 'Quán An');
  });

  test('chuyển quán chỉ cập nhật lựa chọn khi database chấp thuận', () async {
    await repository.selectShop('shop-2');
    expect(repository.selectedShopId, 'shop-2');

    repository.failure = const OwnerOnlyFailure();
    await expectLater(repository.selectShop('shop-forbidden'),
        throwsA(isA<OwnerOnlyFailure>()));
    expect(repository.selectedShopId, 'shop-2');
  });

  test('hộp thư nhận và từ chối lời mời, bỏ lời mời đã xử lý', () async {
    final first = _invite('invite-1');
    final second = _invite('invite-2');
    repository.invites = [first, second];
    final inbox = InboxController(repository);
    await inbox.load();

    expect(await inbox.accept(first), isNull);
    expect(repository.acceptedInviteIds, ['invite-1']);
    expect(inbox.invites.map((i) => i.id), ['invite-2']);

    expect(await inbox.decline(second), isNull);
    expect(repository.declinedInviteIds, ['invite-2']);
    expect(inbox.invites, isEmpty);
    inbox.dispose();
  });

  test('lỗi quyền khi xử lý lời mời được báo và không xóa lời mời', () async {
    final invite = _invite('invite-1');
    repository.invites = [invite];
    final inbox = InboxController(repository);
    await inbox.load();
    repository.failure = const OwnerOnlyFailure();

    final message = await inbox.accept(invite);
    expect(message, isNotNull);
    expect(inbox.invites, [invite]);
    inbox.dispose();
  });

  test('mời nhân viên yêu cầu tên và ít nhất một kênh liên hệ', () async {
    final team = TeamController(repository);
    expect(await team.invite(fullName: ''), isFalse);
    expect(team.nameError, isNotNull);
    expect(team.formError, isNotNull);
    expect(repository.inviteStaffCalls, 0);

    expect(
      await team.invite(
        phone: '0901 234 567',
        email: 'AN@EXAMPLE.COM',
        fullName: ' An ',
      ),
      isTrue,
    );
    expect(repository.inviteStaffCalls, 1);
  });

  test('lỗi quyền khi mời nhân viên không giả thành công', () async {
    repository.failure = const OwnerOnlyFailure();
    final team = TeamController(repository);

    expect(
      await team.invite(phone: '0901 234 567', fullName: 'An'),
      isFalse,
    );
    expect(team.formError, isNotNull);
    expect(repository.inviteStaffCalls, 0);
  });
}

Invite _invite(String id) => Invite(
      id: id,
      shopId: 'shop-1',
      shopName: 'Quán An',
      invitedName: 'Bình',
      invitedByName: 'An',
      createdAt: DateTime.utc(2026),
    );
