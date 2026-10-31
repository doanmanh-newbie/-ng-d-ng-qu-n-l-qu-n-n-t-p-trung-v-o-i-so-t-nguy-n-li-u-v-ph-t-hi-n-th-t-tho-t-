import 'package:flutter/foundation.dart';

import 'owner_dashboard_models.dart';
import 'owner_dashboard_repository.dart';

/// Điều phối tải/làm mới dữ liệu dùng chung cho các màn chủ quán.
class OwnerDashboardController extends ChangeNotifier {
  OwnerDashboardController(this._repository);

  final OwnerDashboardDataSource _repository;

  OwnerDashboardData? data;
  Object? failure;
  bool loading = true;
  bool refreshing = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed) return;
    if (data == null) {
      loading = true;
    } else if (refresh) {
      refreshing = true;
    }
    failure = null;
    notifyListeners();
    try {
      final loaded = await _repository.load();
      if (!_disposed) data = loaded;
    } catch (error) {
      if (!_disposed) failure = error;
    } finally {
      if (!_disposed) {
        loading = false;
        refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveReview(
      OwnerShiftReport report, bool handled, String? note) async {
    await _repository.setShiftReview('${report.shift['id']}', handled, note);
    await load(refresh: true);
  }

  Future<void> markNotificationsRead(
      Iterable<OwnerNotification> notices) async {
    final keys = notices
        .where((notice) => !notice.read)
        .map((notice) => notice.id)
        .toList();
    if (keys.isEmpty) return;
    await _repository.markNotificationsRead(keys);
    await load(refresh: true);
  }
}
