/// Tài khoản đăng nhập (Supabase Auth): id, email và/hoặc số điện thoại, tên hiển thị.
/// Chủ quán đăng nhập bằng email + mật khẩu; nhân viên bằng mã xác nhận (OTP)
/// gửi tới số điện thoại hoặc email.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email = '',
    this.phone = '',
    this.displayName = '',
    this.birthDate = '',
  });

  final String id;
  final String email;

  /// Dạng quốc tế không dấu "+" như Supabase lưu (ví dụ `84901234567`), hoặc rỗng.
  final String phone;

  /// Tên hiển thị người dùng tự nhập lúc đăng nhập lần đầu (rỗng nếu chưa có).
  final String displayName;
  final String birthDate;

  /// Cái để hiện cho người dùng nhận ra tài khoản của mình.
  String get contact => phone.isNotEmpty ? '+$phone' : email;
}

enum StaffRole {
  owner,
  staff;

  static StaffRole parse(String value) => switch (value) {
        'owner' => StaffRole.owner,
        'staff' => StaffRole.staff,
        _ => throw ArgumentError.value(value, 'role', 'ROLE_INVALID'),
      };

  bool get isOwner => this == StaffRole.owner;
}

/// Hồ sơ trong quán đang chọn: kết quả của hàm `my_profile()` ở database.
/// Một tài khoản đăng nhập được mà chưa có hồ sơ nghĩa là chưa thuộc quán nào
/// (chưa nhận/chấp nhận lời mời, hoặc chưa tạo quán).
class Profile {
  const Profile({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.hasPin,
    required this.active,
    this.shopId = '',
    this.shopName = '',
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        staffId: map['staff_id'] as String,
        fullName: map['full_name'] as String,
        role: StaffRole.parse(map['role'] as String),
        hasPin: map['has_pin'] as bool,
        active: map['active'] as bool,
        shopId: (map['shop_id'] as String?) ?? '',
        shopName: (map['shop_name'] as String?) ?? '',
      );

  final String staffId;
  final String fullName;
  final StaffRole role;
  final bool hasPin;
  final bool active;
  final String shopId;
  final String shopName;
}
