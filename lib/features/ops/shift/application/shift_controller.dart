import '../../../../core/application/action_notifier.dart';
import '../../../../core/errors/app_failure.dart';
import '../domain/shift_models.dart';
import '../domain/shift_repository.dart';

enum OpsShiftPhase { loading, ready, error }

/// Trạng thái ca của cả quán: tên quán, ca đang mở (hoặc chưa), và việc còn thiếu trước khi đóng ca.
/// Mọi tab trong màn chính dựa vào controller này để biết có được dùng không.
class OpsShiftController extends ActionNotifier {
  OpsShiftController(this._repo);

  final OpsShiftRepository _repo;

  OpsShiftPhase phase = OpsShiftPhase.loading;
  ShopInfo? shop;
  OpsCurrentShift? shift;
  CloseStatus? closeStatus;
  AppFailure? failure;

  bool get hasOpenShift => shift != null;
  String get shopName => shop?.name ?? 'Fore';
  String get servingLabel => shop?.servingLabel ?? 'phần';

  /// Tải hồ sơ quán và ca đang mở. Gọi khi vào màn hình, và khi kéo để làm mới.
  Future<void> load() async {
    // Chỉ hiện vòng chờ ở lần tải đầu; các lần sau giữ nguyên giao diện cho đỡ nháy.
    if (shift == null && shop == null) {
      phase = OpsShiftPhase.loading;
      notify();
    }
    try {
      // The profile and the open shift are separate requests. The profile name
      // is already available from authentication, so a missing optional
      // shop_info RPC must not blank the entire signed-in home screen.
      try {
        shop = await _repo.shopInfo();
      } on AppFailure {
        shop = null;
      }
      shift = await _repo.currentShift();
      if (shift == null) closeStatus = null;
      failure = null;
      phase = OpsShiftPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      // Có dữ liệu cũ thì giữ dùng tiếp (mất mạng thoáng qua không nên đẩy người dùng ra ngoài).
      phase = (shop != null || shift != null)
          ? OpsShiftPhase.ready
          : OpsShiftPhase.error;
    }
    notify();
  }

  @override
  Future<void> onStale() => load();

  /// Mở ca với số tiền có trong két lúc bắt đầu. Trả `true` nếu đã mở.
  Future<bool> openShift(int openingCash) async {
    final done = await runAction<bool>(() async {
      await _repo.openShift(openingCash);
      await load();
      return true;
    });
    return done ?? false;
  }

  /// Tải danh sách việc còn thiếu trước khi đóng ca (bill đang mở, nguyên liệu chưa đếm).
  Future<void> loadCloseStatus() async {
    if (!hasOpenShift) return;
    try {
      closeStatus = await _repo.closeStatus();
      failure = null;
    } on AppFailure catch (f) {
      failure = f;
      if (f.code == 'NO_OPEN_SHIFT') await load();
    }
    notify();
  }

  /// Đóng ca với số tiền đếm được trong két. Trả `true` nếu đã đóng.
  Future<bool> closeShift(int closingCash) async {
    final done = await runAction<bool>(() async {
      try {
        await _repo.closeShift(closingCash);
      } on AppFailure {
        // Bị từ chối (còn bill mở / thiếu kiểm kê...): cập nhật lại danh sách việc còn thiếu.
        await loadCloseStatus();
        rethrow;
      }
      shift = null;
      closeStatus = null;
      notify();
      return true;
    });
    return done ?? false;
  }
}
