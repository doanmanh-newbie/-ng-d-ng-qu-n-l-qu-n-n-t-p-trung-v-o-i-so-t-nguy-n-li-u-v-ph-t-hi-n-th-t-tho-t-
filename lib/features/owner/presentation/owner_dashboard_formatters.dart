part of 'owner_home_screen.dart';

String _businessDayLabel(OwnerDashboardData data) =>
    'Ngày kinh doanh: ${formatHm(data.businessStart)} · ${data.businessStart.day}/${data.businessStart.month} – 05:59 hôm sau';

String _shortDate(DateTime date) => '${date.day}/${date.month}';

String _minimumStock(Map<String, dynamic> ingredient, OwnerDashboardData data) {
  final matching = data.lowStock
      .where((item) => item['ingredient_id'] == ingredient['ingredient_id']);
  if (matching.isEmpty) return '';
  final threshold = _number(matching.first['minimum_qty']);
  return ' · Ngưỡng ${formatQuantity(threshold, unit: '${ingredient['unit'] ?? ''}')}';
}

bool _isBelowThreshold(
  Map<String, dynamic> ingredient,
  OwnerDashboardData data,
) =>
    data.lowStock
        .any((item) => item['ingredient_id'] == ingredient['ingredient_id']);

StatusSeverity _stockSeverity(int quantity, {bool belowThreshold = false}) =>
    quantity < 0
        ? StatusSeverity.critical
        : belowThreshold
            ? StatusSeverity.attention
            : StatusSeverity.healthy;

List<Map<String, dynamic>> _stockRowsBySeverity(OwnerDashboardData data) {
  final rows = data.expectedStock.toList();
  int rank(Map<String, dynamic> row) {
    if (row['expected_qty'] == null) return 3;
    final severity = _stockSeverity(
      _number(row['expected_qty']),
      belowThreshold: _isBelowThreshold(row, data),
    );
    return switch (severity) {
      StatusSeverity.critical => 0,
      StatusSeverity.attention => 1,
      StatusSeverity.healthy => 2,
      StatusSeverity.neutral => 3,
    };
  }

  rows.sort((a, b) {
    final bySeverity = rank(a).compareTo(rank(b));
    return bySeverity != 0
        ? bySeverity
        : '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}');
  });
  return rows;
}

String _stockStatusLabel(Map<String, dynamic> row, OwnerDashboardData data) {
  final quantity = _number(row['expected_qty']);
  if (quantity < 0) return 'Tồn âm';
  return _isBelowThreshold(row, data) ? 'Dưới ngưỡng' : 'Đủ tồn';
}

StatusSeverity _reportStatusSeverity(String status) => switch (status) {
      'alert' => StatusSeverity.critical,
      'warn' => StatusSeverity.attention,
      'ok' => StatusSeverity.healthy,
      _ => StatusSeverity.neutral,
    };

String _reportStatusLabel(String status) => switch (status) {
      'alert' => 'Lệch lớn',
      'warn' => 'Cần kiểm tra',
      'ok' => 'Ổn',
      _ => 'Chưa đủ dữ liệu',
    };

StatusChip _reportStatusChip(String status, {bool compact = false}) =>
    StatusChip(
      label: _reportStatusLabel(status),
      severity: _reportStatusSeverity(status),
      compact: compact,
    );

Color _reportStatusColor(String status) =>
    switch (_reportStatusSeverity(status)) {
      StatusSeverity.critical => AppColors.statusOff,
      StatusSeverity.attention => AppColors.statusWatch,
      StatusSeverity.healthy => AppColors.statusOk,
      StatusSeverity.neutral => AppColors.textSecondary,
    };

String _quantityOrDash(dynamic value, String unit) =>
    value is num ? formatQuantity(value.round(), unit: unit) : '—';

String _signedQuantityOrDash(dynamic value, String unit) => value is num
    ? '${value > 0 ? '+' : ''}${formatQuantity(value.round(), unit: unit)}'
    : '—';

String _shiftLabel(Map<String, dynamic> shift) {
  final opened = DateTime.tryParse('${shift['opened_at']}')?.toLocal();
  if (opened == null) return 'Ca đã đóng';
  final closed = DateTime.tryParse('${shift['closed_at']}')?.toLocal();
  final day = '${opened.day}/${opened.month}';
  return 'Ca $day · ${formatHm(opened)}${closed == null ? '' : '–${formatHm(closed)}'}';
}

String _cashVarianceLabel(int variance) => variance < 0
    ? 'Tiền mặt thiếu ${formatVnd(variance.abs())}'
    : variance > 0
        ? 'Tiền mặt thừa ${formatVnd(variance)}'
        : 'Tiền mặt khớp';

String _cashVarianceStatus(int variance) => variance < 0
    ? 'Thiếu'
    : variance > 0
        ? 'Thừa'
        : 'Khớp';

StatusSeverity _cashVarianceSeverity(int variance) {
  final amount = variance.abs();
  if (amount >= 50000) return StatusSeverity.critical;
  if (amount >= 20000) return StatusSeverity.attention;
  return StatusSeverity.healthy;
}

int _number(dynamic value) => value is num ? value.round() : 0;

String _errorMessage(Object? error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST202') {
      return 'Database chưa có API của màn chủ quán. Hãy chạy database/012_owner_dashboard.sql sau các file 001–011.';
    }
    if (error.code == '42703' || error.code == '42P01') {
      return 'Database chưa có đủ bảng/cột cho màn chủ quán. Hãy cài schema nhiều quán mới nhất.';
    }
    return 'Không đọc được dữ liệu từ database (${error.code ?? 'lỗi truy vấn'}).';
  }
  return 'Không tải được dữ liệu quán. Hãy kiểm tra kết nối và thử lại.';
}
