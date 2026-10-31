part of 'owner_home_screen.dart';

extension _OwnerReconciliation on _OwnerHomeContentState {
  Widget _reconcileList(OwnerDashboardData data) => PageScaffold(
        header: _pageHeader(),
        children: [
          Row(children: [
            if (_selectedReport != null)
              IconButton(
                onPressed: () => _updateState(() => _selectedReport = null),
                icon: const Icon(Icons.arrow_back),
              ),
            const Expanded(
              child: Text('Đối soát', style: AppTextStyles.display),
            ),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ]),
          if (data.reports.isEmpty)
            const _InfoCard(
              icon: Icons.fact_check_outlined,
              title: 'Chưa có ca để đối soát',
              body: 'Đóng ca đầu tiên để xem báo cáo tiền mặt và nguyên liệu.',
            )
          else
            ...data.reports.map((report) => _ReportCard(
                  report: report,
                  onTap: () => _updateState(() => _selectedReport = report),
                )),
        ],
      );

  Widget _reconcileDetail(OwnerShiftReport report) {
    final cash = report.cash;
    final variance = _number(cash['variance']);
    final ingredients = report.report['ingredients'] is List
        ? (report.report['ingredients'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : <Map<String, dynamic>>[];
    final flagged = ingredients
        .where((row) => row['status'] == 'warn' || row['status'] == 'alert')
        .toList();
    final cashMovements = report.report['cash_movements'] is List
        ? (report.report['cash_movements'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : <Map<String, dynamic>>[];
    final shift = report.shift;
    return PageScaffold(
      header: _pageHeader(),
      children: [
        Row(children: [
          IconButton(
            onPressed: () => _updateState(() => _selectedReport = null),
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
              child: Text('Chi tiết đối soát', style: AppTextStyles.display)),
        ]),
        Text(_shiftLabel(shift), style: AppTextStyles.caption),
        const SizedBox(height: 14),
        _CashResultCard(
          cash: cash,
          variance: variance,
          severity: report.overall == 'no_data'
              ? StatusSeverity.neutral
              : _cashVarianceSeverity(variance),
        ),
        const SizedBox(height: 16),
        _ReviewEditor(
          report: report,
          onSave: (handled, note) => _saveShiftReview(report, handled, note),
        ),
        const SizedBox(height: 16),
        const _SectionTitle(title: 'Dòng tiền trong ca'),
        _KeyValueCard(rows: [
          ('Tiền đầu ca ghi sổ', formatVnd(_number(cash['opening_cash']))),
          ('Chênh đầu ca', formatVnd(_number(cash['opening_diff']))),
          ('Tiền bán tiền mặt', formatVnd(_number(cash['cash_sales']))),
          ('Tiền bán chuyển khoản', formatVnd(_number(cash['transfer_sales']))),
          ('Thu khác', formatVnd(_number(cash['cash_in']))),
          ('Chi trong ca', formatVnd(-_number(cash['cash_out']))),
          (
            'Bill hủy sau khi đã thu',
            '${_number(cash['cancelled_after_paid_count'])} bill · ${formatVnd(_number(cash['cancelled_after_paid_amount']))}'
          ),
          ('Kỳ vọng cuối ca', formatVnd(_number(cash['expected_cash']))),
          ('Thực đếm cuối ca', formatVnd(_number(cash['closing_cash']))),
          ('Chênh lệch cuối ca', formatVnd(variance)),
        ]),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Phiếu thu / chi trong ca'),
        if (cashMovements.isEmpty)
          const _InfoCard(
            icon: Icons.receipt_long_outlined,
            title: 'Không có phiếu thu / chi',
            body: 'Ca này không ghi nhận khoản thu hoặc chi ngoài bill.',
          )
        else
          ...cashMovements.map((movement) {
            final isIncome = movement['direction'] == 'in';
            final amount = _number(movement['amount']);
            final enteredAt =
                DateTime.tryParse('${movement['entered_at']}')?.toLocal();
            return _InfoCard(
              icon: isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              title: '${isIncome ? 'Thu' : 'Chi'} ${formatVnd(amount)}',
              body: [
                if ('${movement['note'] ?? ''}'.trim().isNotEmpty)
                  '${movement['note']}',
                if (movement['entered_by_name'] != null)
                  'Người ghi: ${movement['entered_by_name']}',
                if (enteredAt != null) formatHm(enteredAt),
              ].join(' · '),
            );
          }),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Nguyên liệu cần kiểm tra'),
        if (flagged.isEmpty)
          const _InfoCard(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.statusOk,
            title: 'Không có nguyên liệu bị cảnh báo',
            status: StatusChip(
              label: 'Ổn',
              severity: StatusSeverity.healthy,
              compact: true,
            ),
            body: 'Kết quả dựa trên số kiểm kê và sổ kho của ca này.',
          )
        else
          ...flagged.map((row) => _InfoCard(
                icon: Icons.warning_amber_rounded,
                iconColor: _reportStatusColor('${row['status']}'),
                title: '${row['ingredient_name'] ?? 'Nguyên liệu'}',
                status: _reportStatusChip('${row['status']}', compact: true),
                body:
                    'Lý thuyết ${_quantityOrDash(row['theoretical_used'], '${row['unit'] ?? ''}')} · '
                    'thực dùng ${_quantityOrDash(row['actual_used'], '${row['unit'] ?? ''}')} · '
                    'chênh ${_signedQuantityOrDash(row['adjusted_variance'], '${row['unit'] ?? ''}')}. '
                    'Đây là tín hiệu cần kiểm tra, chưa phải kết luận thất thoát.',
              )),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.info_outline,
          title: 'Đối soát chỉ là tín hiệu cần kiểm tra',
          body:
              'Hãy đối chiếu số đếm, bill và phiếu thu chi trước khi kết luận. Chênh lệch không đồng nghĩa với thất thoát.',
        ),
        _InfoCard(
          icon: Icons.inventory_2_outlined,
          title: 'Kiểm tra kho và hao hụt',
          body: 'Mở kho để xem tồn dự kiến, ghi hao hụt hoặc thu chi tiền mặt.',
          onTap: () => _updateState(() {
            _tab = 3;
            _selectedReport = null;
          }),
        ),
      ],
    );
  }
}
