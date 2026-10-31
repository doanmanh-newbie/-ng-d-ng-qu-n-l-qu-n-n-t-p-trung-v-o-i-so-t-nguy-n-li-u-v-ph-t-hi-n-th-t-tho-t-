import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/auth/application/staff_register_controller.dart';
import 'package:fore/features/auth/domain/staff_contact.dart';
import 'package:fore/features/auth/domain/staff_credentials.dart';

import 'support/fake_auth_repository.dart';

void main() {
  group('StaffCredentials', () {
    test('số điện thoại đổi thành email giả, và đọc ngược lại được', () {
      final c = StaffContact.tryParse(ContactKind.phone, '0901 234 567').contact!;
      final email = StaffCredentials.emailFor(c);
      expect(email, 'p84901234567@phone.fore-staff.app');
      expect(StaffCredentials.phoneFromEmail(email), '84901234567');
      expect(
        StaffCredentials.demoContactMetadata(c),
        {'demo_phone': '+84901234567'},
      );
    });

    test('email thật giữ nguyên, không bị coi là số điện thoại', () {
      final c =
          StaffContact.tryParse(ContactKind.email, ' Lan@Gmail.com ').contact!;
      expect(StaffCredentials.emailFor(c), 'lan@gmail.com');
      expect(StaffCredentials.phoneFromEmail('lan@gmail.com'), isNull);
      expect(
        StaffCredentials.demoContactMetadata(c),
        {'demo_email': 'lan@gmail.com'},
      );
    });
  });

  group('tạo tài khoản rồi đăng nhập', () {
    late FakeAuthRepository repo;
    setUp(() => repo = FakeAuthRepository());

    test('thiếu tên hoặc ngày sinh thì không gọi database', () async {
      final c = StaffRegisterController(repo);
      final ok = await c.submit(
          contactText: '0901234567', fullName: ' ', birthDate: null);
      expect(ok, isFalse);
      expect(c.nameError, isNotNull);
      expect(c.birthDateError, isNotNull);
      expect(repo.signUpStaffCalls, 0);
    });

    test('số điện thoại sai thì báo lỗi ở ô số', () async {
      final c = StaffRegisterController(repo);
      final ok = await c.submit(
          contactText: '123', fullName: 'Lan', birthDate: DateTime(2001, 5, 20));
      expect(ok, isFalse);
      expect(c.contactError, isNotNull);
    });

    test('tạo xong đăng nhập được; tạo lần hai báo đã có tài khoản', () async {
      final register = StaffRegisterController(repo);
      Future<bool> create() => register.submit(
          contactText: '0901 234 567',
          fullName: 'Lan',
          birthDate: DateTime(2001, 5, 20));

      expect(await create(), isTrue);
      expect(await create(), isFalse);
      expect(register.contactError, isNotNull);

      final login = StaffLoginController(repo);
      expect(await login.submit('0901234567'), isTrue);
    });

    test('đăng nhập số chưa đăng ký thì báo ở ô số', () async {
      final login = StaffLoginController(repo);
      expect(await login.submit('0912345678'), isFalse);
      expect(login.contactError, isNotNull);
      expect(login.formError, isNull);
    });

    test('mất mạng thì báo lỗi chung, không gắn vào ô số', () async {
      repo.failure = const NoNetworkFailure();
      final login = StaffLoginController(repo);
      expect(await login.submit('0901234567'), isFalse);
      expect(login.formError, isNotNull);
      expect(login.contactError, isNull);
    });
  });
}
