import 'package:flutter/foundation.dart';

import 'owner_dashboard_models.dart';
import 'owner_dashboard_repository.dart';

/// Điều phối tải/làm mới dữ liệu dùng chung cho các màn chủ quán.
class OwnerDashboardController extends ChangeNotifier {
  OwnerDashboardController(this._repository);

  final OwnerDashboardRepository _repository;

  OwnerDashboardData? data;
  Object? failure;
  bool loading = true;
  bool refreshing = false;

  Future<void> load({bool refresh = false}) async {
    if (data == null) {
      loading = true;
    } else if (refresh) {
      refreshing = true;
    }
    failure = null;
    notifyListeners();
    try {
      data = await _repository.load();
    } catch (error) {
      failure = error;
    } finally {
      loading = false;
      refreshing = false;
      notifyListeners();
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
