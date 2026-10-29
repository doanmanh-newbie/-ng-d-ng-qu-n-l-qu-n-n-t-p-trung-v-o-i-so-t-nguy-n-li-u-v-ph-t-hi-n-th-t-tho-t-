import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Trạng thái phiên làm việc. `sealed`: màn hình phải xử lý đủ mọi trạng thái.
sealed class SessionState {
  const SessionState();
}

/// Đang kiểm tra đăng nhập đã lưu (màn Splash).
class SessionChecking extends SessionState {
  const SessionChecking();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.profile);

  final Profile profile;
}

/// Đăng nhập được nhưng chưa thuộc quán nào: nhân viên chờ lời mời trong hộp thư,
/// hoặc chủ quán chưa tạo quán.
class SessionNoShop extends SessionState {
  const SessionNoShop(this.contact, {this.displayName = ''});

  /// Số điện thoại hoặc email của tài khoản (hiện cho người dùng nhận ra mình).
  final String contact;

  /// Tên hiển thị người dùng đã nhập (có thể rỗng).
  final String displayName;
}

/// Không kiểm tra được vì không có mạng hoặc quá thời gian chờ.
class SessionOffline extends SessionState {
  const SessionOffline();
}

/// Giữ phiên làm việc của cả app. Các màn hình lắng nghe đối tượng này.
class SessionController extends ChangeNotifier {
  SessionController(
    this._repository, {
    this.minVisible = const Duration(milliseconds: 1400),
    this.timeout = const Duration(seconds: 10),
  });

  final AuthRepository _repository;

  /// Splash hiện tối thiểu bấy lâu, kể cả khi kiểm tra xong sớm.
  /// Bằng thời lượng chuyển động logo (1400 ms) để hoạt ảnh không bị cắt giữa chừng.
  final Duration minVisible;

  /// Quá bấy lâu thì coi như không có mạng.
  final Duration timeout;

  SessionState _state = const SessionChecking();
  SessionState get state => _state;

  /// Người dùng chọn "Chủ quán" ở màn đầu. Chỉ dùng để quyết định đi đâu khi chưa có quán
  /// (chủ -> màn Tạo quán; nhân viên -> không gian nhân viên chờ lời mời).
  /// Quyền thật luôn do database quyết định theo vai trò trong từng quán.
  bool ownerIntent = false;

  /// Kiểm tra đăng nhập đã lưu. Gọi khi mở app và khi bấm "Thử lại".
  ///
  /// `skipMinWait`: bỏ thời gian hiện tối thiểu (dùng khi người dùng tắt hoạt ảnh,
  /// không cần chờ cho xem hết chuyển động).
  Future<void> restore({bool skipMinWait = false}) async {
    _set(const SessionChecking());
    final minDelay =
        skipMinWait ? Future<void>.value() : Future<void>.delayed(minVisible);
    SessionState next;
    try {
      next = await _resolve().timeout(timeout);
    } on TimeoutException {
      next = const SessionOffline();
    } on NoNetworkFailure {
      next = const SessionOffline();
    } on AppFailure {
      // Lỗi lạ: cho đăng nhập lại thay vì kẹt ở splash.
      next = const SessionSignedOut();
    }
    await minDelay;
    _set(next);
  }

  /// Gọi sau khi đăng nhập thành công (hoặc bấm "Kiểm tra lại") để tải hồ sơ.
  ///
  /// Trả về `null` nếu xong. Nếu lỗi (mất mạng, lỗi máy chủ...) trả về lỗi đó để
  /// màn hình hiện cho người dùng, và giữ nguyên trạng thái cũ.
  Future<AppFailure?> refreshAfterSignIn() async {
    try {
      _set(await _resolve());
      return null;
    } on AppFailure catch (f) {
      return f;
    }
  }

  /// Trả về `null` nếu đăng xuất xong; nếu lỗi (ví dụ mất mạng) thì giữ nguyên
  /// trạng thái và trả về lỗi để màn hình báo cho người dùng.
  Future<AppFailure?> signOut() async {
    try {
      await _repository.signOut();
    } on AppFailure catch (f) {
      return f;
    }
    ownerIntent = false;
    _set(const SessionSignedOut());
    return null;
  }

  Future<SessionState> _resolve() async {
    final user = _repository.currentUser;
    if (user == null) return const SessionSignedOut();
    final profile = await _repository.fetchProfile();
    if (profile == null || !profile.active) {
      return SessionNoShop(user.contact, displayName: user.displayName);
    }
    return SessionSignedIn(profile);
  }

  void _set(SessionState next) {
    _state = next;
    notifyListeners();
  }
}
