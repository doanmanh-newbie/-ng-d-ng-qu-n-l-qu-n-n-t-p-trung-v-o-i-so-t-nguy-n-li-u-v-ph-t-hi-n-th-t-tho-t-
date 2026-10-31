import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/owner_dashboard_models.dart';

abstract interface class OwnerDashboardDataSource {
  Future<OwnerDashboardData> load();

  Future<void> setShiftReview(String shiftId, bool handled, String? note);

  Future<void> markNotificationsRead(List<String> keys);
}

/// Dữ liệu thật dành cho dashboard chủ quán. Không dùng số minh họa từ bản thiết kế.
class OwnerDashboardRepository implements OwnerDashboardDataSource {
  OwnerDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OwnerDashboardData> load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final businessStart = now.hour < 6
        ? today.subtract(const Duration(days: 1)).add(const Duration(hours: 6))
        : today.add(const Duration(hours: 6));
    final businessEnd = businessStart.add(const Duration(days: 1));

    final dashboardResult = await _client.rpc(
      'owner_dashboard',
      params: {
        'p_from': businessStart.toUtc().toIso8601String(),
        'p_to': businessEnd.toUtc().toIso8601String(),
      },
    );
    if (dashboardResult is! Map) {
      throw const FormatException('owner_dashboard trả sai định dạng');
    }
    final dashboard = Map<String, dynamic>.from(dashboardResult);
    final shifts = (dashboard['reports'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row['shift'] as Map))
        .toList(growable: false);
    final reports = (dashboard['reports'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((row) => row['report'] is Map)
        .map((row) => OwnerShiftReport(
              shift: Map<String, dynamic>.from(row['shift'] as Map),
              report: Map<String, dynamic>.from(row['report'] as Map),
              review:
                  Map<String, dynamic>.from(row['review'] as Map? ?? const {}),
            ))
        .toList(growable: false);
    final secondary = await Future.wait<dynamic>([
      _client.rpc('menu_for_sale'),
      _client
          .from('v_expected_stock')
          .select('ingredient_id, name, unit, expected_qty, last_count_at'),
      _client.from('recipe_lines').select('size_id'),
      _client.rpc('owner_sales_trend', params: {
        'p_business_start': businessStart.toUtc().toIso8601String(),
        'p_days': 7,
      }),
    ]);
    final recipeSizeIds = (secondary[2] as List<dynamic>)
        .whereType<Map>()
        .map((row) => '${row['size_id']}')
        .toSet();
    final menu = (secondary[0] as List<dynamic>).map((row) {
      final menuRow = Map<String, dynamic>.from(row as Map);
      menuRow['has_recipe'] = recipeSizeIds.contains('${menuRow['size_id']}');
      return menuRow;
    }).toList(growable: false);
    final expectedStock = (secondary[1] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final recentSales = (secondary[3] as List<dynamic>)
        .whereType<Map>()
        .map((row) => DailySalesPoint.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final notifications = (dashboard['notifications'] as List<dynamic>? ??
            const [])
        .whereType<Map>()
        .map((row) => OwnerNotification.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return OwnerDashboardData(
      shifts: shifts,
      reports: reports,
      openShift: dashboard['open_shift'] is Map
          ? Map<String, dynamic>.from(dashboard['open_shift'] as Map)
          : null,
      cashSales: (dashboard['cash_sales'] as num?)?.toInt() ?? 0,
      transferSales: (dashboard['transfer_sales'] as num?)?.toInt() ?? 0,
      yesterdaySales: (dashboard['yesterday_sales'] as num?)?.toInt() ?? 0,
      billCount: (dashboard['bill_count'] as num?)?.toInt() ?? 0,
      pendingInvites: (dashboard['pending_invites'] as num?)?.toInt() ?? 0,
      activeStaffCount: (dashboard['active_staff_count'] as num?)?.toInt() ?? 0,
      menu: menu,
      expectedStock: expectedStock,
      lowStock: (dashboard['low_stock'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      notifications: notifications,
      missingRecipeCount:
          (dashboard['missing_recipe_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.now(),
      businessStart: businessStart,
      businessEnd: businessEnd,
      recentSales: recentSales,
    );
  }

  @override
  Future<void> setShiftReview(
      String shiftId, bool handled, String? note) async {
    await _client.rpc('set_shift_review', params: {
      'p_shift': shiftId,
      'p_handled': handled,
      'p_note': note,
    });
  }

  @override
  Future<void> markNotificationsRead(List<String> keys) async {
    await _client.rpc('mark_owner_notifications_read', params: {
      'p_keys': keys,
    });
  }
}
