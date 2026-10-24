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

/// Đăng nhập được nhưng chủ quán chưa thêm vào quán (hoặc đã bị tắt).
class SessionNotLinked extends SessionState {
  const SessionNotLinked(this.email);

  final String email;
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

  /// Gọi sau khi đăng nhập thành công để tải hồ sơ trong quán.
  Future<void> refreshAfterSignIn() async {
    try {
      _set(await _resolve());
    } on NoNetworkFailure {
      _set(const SessionOffline());
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _set(const SessionSignedOut());
  }

  Future<SessionState> _resolve() async {
    final user = _repository.currentUser;
    if (user == null) return const SessionSignedOut();
    final profile = await _repository.fetchProfile();
    if (profile == null || !profile.active) return SessionNotLinked(user.email);
    return SessionSignedIn(profile);
  }

  void _set(SessionState next) {
    _state = next;
    notifyListeners();
  }
}
