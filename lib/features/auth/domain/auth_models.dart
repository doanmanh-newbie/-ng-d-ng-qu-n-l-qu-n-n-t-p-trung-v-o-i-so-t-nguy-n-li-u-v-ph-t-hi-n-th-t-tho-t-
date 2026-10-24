/// Tài khoản đăng nhập (Supabase Auth). Chỉ có id và email.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
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

/// Hồ sơ trong quán: kết quả của hàm `my_profile()` ở database.
/// Một tài khoản đăng nhập được mà chưa có hồ sơ nghĩa là
/// chủ quán chưa thêm người này vào quán.
class Profile {
  const Profile({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.hasPin,
    required this.active,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        staffId: map['staff_id'] as String,
        fullName: map['full_name'] as String,
        role: StaffRole.parse(map['role'] as String),
        hasPin: map['has_pin'] as bool,
        active: map['active'] as bool,
      );

  final String staffId;
  final String fullName;
  final StaffRole role;
  final bool hasPin;
  final bool active;
}
