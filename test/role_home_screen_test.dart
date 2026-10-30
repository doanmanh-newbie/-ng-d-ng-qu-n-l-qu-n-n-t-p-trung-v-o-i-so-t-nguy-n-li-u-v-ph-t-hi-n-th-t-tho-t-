import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/home/role_home_screen.dart';

void main() {
  test('chọn không gian chủ/nhân viên theo vai trò trong hồ sơ', () {
    expect(RoleHomeScreen.isOwnerRole(StaffRole.owner), isTrue);
    expect(RoleHomeScreen.isOwnerRole(StaffRole.staff), isFalse);
  });
}
