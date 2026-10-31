part of 'owner_home_screen.dart';

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.data});
  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final change = data.salesChangePercent;
    final businessDayComplete = !DateTime.now().isBefore(data.businessEnd);
    final changeLabel = !businessDayComplete
        ? 'Chưa so sánh: ngày kinh doanh chưa kết thúc.'
        : change == null
            ? 'Chưa có dữ liệu ngày kinh doanh trước'
            : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% so với ngày kinh doanh trước';
    return ForeCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Doanh thu hôm nay', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(formatVnd(data.totalSales), style: AppTextStyles.metricXL),
        const SizedBox(height: 6),
        Text(
          'Tiền mặt ${formatVnd(data.cashSales)} · Chuyển khoản ${formatVnd(data.transferSales)}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        const Text('Doanh thu 7 ngày', style: AppTextStyles.captionStrong),
        const SizedBox(height: 6),
        _SalesTrendBars(points: data.recentSales),
        const SizedBox(height: 4),
        Text(changeLabel, style: AppTextStyles.caption),
      ]),
    );
  }
}

class _SalesTrendBars extends StatelessWidget {
  const _SalesTrendBars({required this.points});

  final List<DailySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('Chưa có dữ liệu 7 ngày.',
          style: AppTextStyles.caption);
    }
    final maxSales = points.fold<int>(1, (max, point) {
      return point.sales > max ? point.sales : max;
    });
    return SizedBox(
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Semantics(
                label:
                    '${point.businessStart.day}/${point.businessStart.month}, doanh thu ${formatVnd(point.sales)}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: point.sales == 0
                              ? 3
                              : 8 + 34 * point.sales / maxSales,
                          decoration: BoxDecoration(
                            color: point == points.last
                                ? AppColors.brandAccent
                                : AppColors.statusHealthyTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 12,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${point.businessStart.day}',
                                style: AppTextStyles.micro),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.onOpenOps});
  final Map<String, dynamic>? shift;
  final VoidCallback onOpenOps;

  @override
  Widget build(BuildContext context) => _InfoCard(
        icon: shift == null ? Icons.schedule_outlined : Icons.circle,
        title: shift == null ? 'Chưa có ca đang mở' : 'Ca đang mở',
        body: shift == null
            ? 'Mở màn hình vận hành để bắt đầu ca.'
            : 'Ca của ${shift!['opened_by_name'] ?? 'nhân viên'} · mở lúc ${formatHm(DateTime.parse(shift!['opened_at'] as String).toLocal())}',
        onTap: onOpenOps,
        showArrow: true,
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    this.featured = false,
    this.onCheckStock,
  });
  final OwnerShiftReport report;
  final VoidCallback onTap;
  final bool featured;
  final VoidCallback? onCheckStock;

  @override
  Widget build(BuildContext context) {
    final cash = report.cash;
    final variance = _number(cash['variance']);
    final status = report.overall;
    final ingredients = report.report['ingredients'] is List
        ? (report.report['ingredients'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['status'] == 'warn' || row['status'] == 'alert')
            .toList()
        : <Map<String, dynamic>>[];
    final primary = ingredients.isEmpty ? null : ingredients.first;
    final summary = primary == null
        ? 'Nguyên liệu: không có cảnh báo'
        : '${primary['ingredient_name']}: ${_signedQuantityOrDash(primary['adjusted_variance'], '${primary['unit'] ?? ''}')}'
            '${primary['equiv_revenue'] == null ? '' : ' · ước tính ≈ ${formatVnd(_number(primary['equiv_revenue']))}'}';
    final openedBy = report.shift['opened_by_name'] ?? 'Nhân viên';
    if (featured && (status == 'alert' || status == 'warn')) {
      final actual = primary == null
          ? null
          : _quantityOrDash(primary['actual_used'], '${primary['unit'] ?? ''}');
      final theoretical = primary == null
          ? null
          : _quantityOrDash(
              primary['theoretical_used'], '${primary['unit'] ?? ''}');
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
        child: HeroCard(
          title: _shiftLabel(report.shift),
          status: _reportStatusChip(status, compact: true),
          primaryLabel: 'Xem chi tiết đối soát',
          onPrimary: onTap,
          secondaryLabel: 'Kiểm tra kho & hao hụt',
          onSecondary: onCheckStock,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ca của $openedBy',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                primary == null
                    ? _cashVarianceLabel(variance)
                    : _signedQuantityOrDash(
                        primary['adjusted_variance'],
                        '${primary['unit'] ?? ''}',
                      ),
                style: AppTextStyles.headline.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                primary == null
                    ? 'Chênh lệch tiền mặt cần kiểm tra'
                    : '${primary['ingredient_name'] ?? 'Nguyên liệu'} · chênh lệch cần kiểm tra',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                  'Tiền mặt · ${variance < 0 ? 'thiếu' : variance > 0 ? 'thừa' : 'khớp'} ${formatVnd(variance.abs())}',
                  style: AppTextStyles.body.copyWith(color: Colors.white)),
              if (primary != null) ...[
                const SizedBox(height: 4),
                Text('Lý thuyết $theoretical · Thực dùng $actual',
                    style:
                        AppTextStyles.caption.copyWith(color: Colors.white70)),
              ],
              const SizedBox(height: 10),
              StatusChip(
                label: report.handled ? 'Đã xử lý' : 'Chưa xử lý',
                severity: report.handled
                    ? StatusSeverity.healthy
                    : StatusSeverity.attention,
                compact: true,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
      child: ForeCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child:
                    Text(_shiftLabel(report.shift), style: AppTextStyles.title),
              ),
              const SizedBox(width: 8),
              _reportStatusChip(status, compact: true),
            ]),
            const SizedBox(height: 8),
            Text('Nhân viên: $openedBy', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            _ReportMetricRow(
              label: 'Tiền mặt',
              value: _cashVarianceLabel(variance),
              emphasis: true,
            ),
            const SizedBox(height: 5),
            _ReportMetricRow(label: 'Nguyên liệu', value: summary),
            const SizedBox(height: 10),
            Row(children: [
              StatusChip(
                label: report.handled ? 'Đã xử lý' : 'Chưa xử lý',
                severity: report.handled
                    ? StatusSeverity.healthy
                    : StatusSeverity.attention,
                compact: true,
              ),
              const Spacer(),
              const Text('Xem chi tiết', style: AppTextStyles.bodyStrong),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.brand),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ReportMetricRow extends StatelessWidget {
  const _ReportMetricRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(
              value,
              style: emphasis
                  ? TextStyle(
                      fontSize: AppFontSizes.s15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: _cashVarianceColor(value),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )
                  : AppTextStyles.bodyStrong,
            ),
          ),
        ],
      );
}

Color _cashVarianceColor(String label) => label.contains('thiếu')
    ? AppColors.statusCritical
    : label.contains('thừa')
        ? AppColors.statusAttention
        : AppColors.statusHealthy;
