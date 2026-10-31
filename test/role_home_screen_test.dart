import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/home/role_home_screen.dart';
import 'support/fake_auth_repository.dart';

void main() {
  test('chọn không gian chủ/nhân viên theo vai trò trong hồ sơ', () {
    expect(RoleHomeScreen.isOwnerRole(StaffRole.owner), isTrue);
    expect(RoleHomeScreen.isOwnerRole(StaffRole.staff), isFalse);
  });

  testWidgets('nhân viên không được hiển thị các tab chủ quán',
      (tester) async {
    final auth = FakeAuthRepository()
      ..user = const AuthUser(id: 'staff-1', email: 'staff@example.test')
      ..profile = const Profile(
        staffId: 'staff-1',
        fullName: 'Nhân viên QA',
        role: StaffRole.staff,
        hasPin: false,
        active: true,
      );
    final session = SessionController(auth, minVisible: Duration.zero);
    await tester.runAsync(session.refreshAfterSignIn);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          home: RoleHomeScreen(
            staffHomeBuilder: (_) =>
                const Scaffold(body: Text('Giao diện nhân viên')),
          ),
        ),
      ),
    );

    expect(find.text('Giao diện nhân viên'), findsOneWidget);
    for (final label in ['Tổng quan', 'Đối soát', 'Thực đơn', 'Kho', 'Thêm']) {
      expect(find.text(label), findsNothing);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
