import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../core/format.dart';
import '../../core/data/rpc_client.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/fore_header.dart';
import '../auth/application/session_controller.dart';
import '../auth/domain/auth_models.dart';
import '../home/home_screen.dart';
import '../inventory/data/rpc_inventory_repository.dart';
import '../inventory/presentation/cash_screen.dart';
import '../inventory/presentation/waste_screen.dart';
import '../more/more_view.dart';
import '../shop/presentation/shop_switcher.dart';
import 'owner_dashboard_repository.dart';
import 'owner_dashboard_controller.dart';
import 'owner_dashboard_models.dart';
import 'presentation/owner_notifications_screen.dart';

/// Trang chủ riêng của chủ quán. Số liệu mẫu trong file thiết kế không được dùng
/// ở đây; mọi chỉ số hiển thị đều lấy từ database hoặc hiện trạng thái trống/lỗi.
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  late final _repository = OwnerDashboardRepository(Supabase.instance.client);
  late final OwnerDashboardController _dashboard;
  int _tab = 0;
  OwnerShiftReport? _selectedReport;

  @override
  void initState() {
    super.initState();
    _dashboard = OwnerDashboardController(_repository)..load();
  }

  @override
  void dispose() {
    _dashboard.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _dashboard.load(refresh: true);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ForeHeader(
              shopName: widget.profile.shopName.isEmpty
                  ? 'Fore'
                  : widget.profile.shopName,
              subtitle: 'Chủ quán · ${widget.profile.fullName}',
              pill: null,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _dashboard,
                builder: (context, _) {
                  final data = _dashboard.data;
                  if (data == null && _dashboard.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (data == null) {
                    return _ErrorPanel(
                      onRetry: _refresh,
                      message: _errorMessage(_dashboard.failure),
                    );
                  }
                  final page = _page(data);
                  if (_dashboard.failure == null) return page;
                  return Column(children: [
                    MaterialBanner(
                      content: Text(_errorMessage(_dashboard.failure)),
                      leading: const Icon(Icons.cloud_off_outlined),
                      actions: [
                        TextButton(
                            onPressed: _refresh, child: const Text('Thử lại')),
                      ],
                    ),
                    Expanded(child: page),
                  ]);
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() {
            _tab = index;
            _selectedReport = null;
          }),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined), label: 'Tổng quan'),
            NavigationDestination(
                icon: Icon(Icons.fact_check_outlined), label: 'Đối soát'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), label: 'Thực đơn'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), label: 'Kho'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Thêm'),
          ],
        ),
      );

  Widget _page(OwnerDashboardData data) {
    if (_tab == 4) return _more(data);
    if (_tab == 1) {
      final report = _selectedReport;
      return report == null ? _reconcileList(data) : _reconcileDetail(report);
    }
    if (_tab == 2) return _menu(data);
    if (_tab == 3) return _stock(data);
    return _overview(data);
  }

  Widget _overview(OwnerDashboardData data) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Tổng quan', style: AppTextStyles.display),
                ),
                IconButton(
                  tooltip: 'Thông báo và lời mời',
                  onPressed: () => _openNotifications(data),
                  icon: _NotificationBell(
                    hasUnread: data.notifications.any((notice) => !notice.read),
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(_businessDayLabel(data), style: AppTextStyles.caption),
            const SizedBox(height: 14),
            _ShiftCard(
              shift: data.openShift,
              onOpenOps: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => OpsHomeScreen(
                    onBackToManagement: _returnToManagement,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _RevenueCard(data: data),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Bill đã thanh toán',
                    value: '${data.billCount}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Doanh thu / bill',
                    value: data.billCount == 0
                        ? '—'
                        : formatVnd(data.totalSales ~/ data.billCount),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Mời nhân viên',
              subtitle:
                  '${data.activeStaffCount} nhân viên đã tạo bill trong ca',
              icon: Icons.person_add_alt_1_outlined,
              enabled: true,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Đối soát',
              trailing: TextButton(
                onPressed: () => setState(() => _tab = 1),
                child: const Text('Xem tất cả'),
              ),
            ),
            if (data.reports.isEmpty)
              const _InfoCard(
                icon: Icons.fact_check_outlined,
                title: 'Chưa có dữ liệu đối soát',
                body:
                    'Báo cáo sẽ xuất hiện sau khi đóng ca và hoàn tất kiểm kê.',
              )
            else
              ...data.reports.take(1).map(
                    (report) => _ReportCard(
                      report: report,
                      onTap: () => setState(() {
                        _tab = 1;
                        _selectedReport = report;
                      }),
                    ),
                  ),
            const SizedBox(height: 20),
            const _SectionTitle(title: 'Cần chú ý'),
            if (data.missingRecipeCount > 0)
              _InfoCard(
                icon: Icons.menu_book_outlined,
                title: '${data.missingRecipeCount} size chưa có công thức',
                body: 'Đối soát nguyên liệu có thể chưa tính đủ phần tiêu hao.',
                onTap: () => setState(() => _tab = 2),
              ),
            for (final item in data.lowStock)
              _InfoCard(
                icon: Icons.inventory_2_outlined,
                title: '${item['name']} dưới ngưỡng tồn',
                body: 'Tồn dự kiến ${item['expected_qty']} ${item['unit']} · '
                    'ngưỡng ${item['minimum_qty']} ${item['unit']}',
                onTap: () => setState(() => _tab = 3),
              ),
            if (data.pendingInvites > 0)
              _InfoCard(
                icon: Icons.person_add_alt_1_outlined,
                title: '${data.pendingInvites} lời mời đang chờ',
                body: 'Mở hộp thư để xem trạng thái lời mời nhân viên.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
              ),
            if (data.missingRecipeCount == 0 &&
                data.lowStock.isEmpty &&
                data.pendingInvites == 0)
              const _InfoCard(
                icon: Icons.check_circle_outline,
                title: 'Không có nhắc việc mới',
                body: 'Các cảnh báo sẽ hiện ở đây khi có dữ liệu cần xem.',
              ),
            const SizedBox(height: 20),
            const _SectionTitle(title: 'Ca gần đây'),
            if (data.reports.isEmpty)
              const _InfoCard(
                icon: Icons.history_rounded,
                title: 'Chưa có ca đã đóng',
                body: 'Lịch sử ca sẽ xuất hiện ở đây sau khi đóng ca.',
              )
            else
              ...data.reports.take(3).map(
                    (report) => _ReportCard(
                      report: report,
                      onTap: () => setState(() {
                        _tab = 1;
                        _selectedReport = report;
                      }),
                    ),
                  ),
            const SizedBox(height: 12),
            Text(
              'Cập nhật lúc ${formatHm(data.updatedAt)} · ngày kinh doanh 06:00–05:59',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );

  Widget _reconcileList(OwnerDashboardData data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(children: [
            if (_selectedReport != null)
              IconButton(
                onPressed: () => setState(() => _selectedReport = null),
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
                  onTap: () => setState(() => _selectedReport = report),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() => _selectedReport = null),
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
              child: Text('Chi tiết đối soát', style: AppTextStyles.display)),
        ]),
        Text(_shiftLabel(shift), style: AppTextStyles.caption),
        const SizedBox(height: 14),
        _CashResultCard(cash: cash, variance: variance),
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
            title: 'Không có nguyên liệu bị cảnh báo',
            body: 'Kết quả dựa trên số kiểm kê và sổ kho của ca này.',
          )
        else
          ...flagged.map((row) => _InfoCard(
                icon: Icons.warning_amber_rounded,
                title:
                    '${row['ingredient_name'] ?? 'Nguyên liệu'} · ${row['status']}',
                body: 'Lý thuyết ${row['theoretical_used'] ?? '—'} · '
                    'thực dùng ${row['actual_used'] ?? '—'} · '
                    'chênh ${row['adjusted_variance'] ?? '—'} ${row['unit'] ?? ''}. '
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
          onTap: () => setState(() {
            _tab = 3;
            _selectedReport = null;
          }),
        ),
      ],
    );
  }

  Widget _menu(OwnerDashboardData data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text('Thực đơn', style: AppTextStyles.display),
          const SizedBox(height: 12),
          if (data.menu.isEmpty)
            const _InfoCard(
              icon: Icons.menu_book_outlined,
              title: 'Chưa có món đang bán',
              body: 'Thêm món và size để bắt đầu nhận đơn.',
            )
          else
            ...data.menu.map((row) => _InfoCard(
                  icon: Icons.local_cafe_outlined,
                  title: '${row['item_name']} · ${row['size_name']}',
                  body: formatVnd(_number(row['price'])),
                )),
          if (data.missingRecipeCount > 0)
            _InfoCard(
              icon: Icons.warning_amber_rounded,
              title: '${data.missingRecipeCount} size thiếu công thức',
              body: 'Cần bổ sung để kết quả đối soát nguyên liệu đầy đủ hơn.',
            ),
        ],
      );

  Widget _stock(OwnerDashboardData data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text('Kho', style: AppTextStyles.display),
          const SizedBox(height: 12),
          if (data.expectedStock.isEmpty)
            const _InfoCard(
              icon: Icons.inventory_2_outlined,
              title: 'Chưa có số liệu tồn kho',
              body: 'Tồn dự kiến sẽ xuất hiện sau khi có kiểm kê.',
            )
          else
            ...data.expectedStock.map((row) => _InfoCard(
                  icon: Icons.inventory_2_outlined,
                  title: '${row['name'] ?? 'Nguyên liệu'}',
                  body: row['expected_qty'] == null
                      ? 'Chưa có lần kiểm kê · ${row['unit'] ?? ''}'
                      : 'Tồn dự kiến ${row['expected_qty']} ${row['unit'] ?? ''}'
                          '${_minimumStock(row, data)}',
                )),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Ghi hao hụt',
            subtitle: data.openShift == null
                ? 'Cần mở ca trước'
                : 'Ghi nhận trong ca đang mở',
            icon: Icons.delete_outline,
            enabled: data.openShift != null,
            onTap: () =>
                Navigator.of(context).push<void>(MaterialPageRoute<void>(
              builder: (_) => WasteScreen(
                  repository: RpcInventoryRepository(
                      SupabaseRpcClient(Supabase.instance.client))),
            )),
          ),
          _ActionCard(
            title: 'Thu / chi tiền mặt',
            subtitle: data.openShift == null
                ? 'Cần mở ca trước'
                : 'Ghi nhận trong ca đang mở',
            icon: Icons.payments_outlined,
            enabled: data.openShift != null,
            onTap: () =>
                Navigator.of(context).push<void>(MaterialPageRoute<void>(
              builder: (_) => CashScreen(
                  repository: RpcInventoryRepository(
                      SupabaseRpcClient(Supabase.instance.client))),
            )),
          ),
        ],
      );

  Widget _more(OwnerDashboardData data) {
    final inventory =
        RpcInventoryRepository(SupabaseRpcClient(Supabase.instance.client));
    return MoreView(
      personName: widget.profile.fullName,
      roleLabel: 'Chủ quán',
      shopName: widget.profile.shopName,
      hasOpenShift: data.openShift != null,
      isOwner: true,
      onWaste: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => WasteScreen(repository: inventory))),
      onCash: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => CashScreen(repository: inventory))),
      onSwitchShop: () => showShopSwitcher(context),
      onInbox: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
      onTeam: () => Navigator.of(context).pushNamed(AppRoutes.team),
      onSignOut: _signOut,
    );
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  Future<void> _returnToManagement() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await _refresh();
  }

  Future<bool> _saveShiftReview(
      OwnerShiftReport report, bool handled, String? note) async {
    try {
      await _dashboard.saveReview(report, handled, note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu trạng thái và ghi chú.')),
        );
      }
      return true;
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
      return false;
    }
  }

  Future<void> _openNotifications(OwnerDashboardData data) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => OwnerNotificationsScreen(
          data: data,
          onMarkRead: _dashboard.markNotificationsRead,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      await _refresh();
      if (!mounted) return;
    }
    if (result == 'invites') {
      await navigator.pushNamed(AppRoutes.inbox);
    } else if (result is OwnerShiftReport) {
      setState(() {
        _tab = 1;
        _selectedReport = result;
      });
    }
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.data});
  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final change = data.salesChangePercent;
    final changeLabel = change == null
        ? 'Chưa có dữ liệu ngày kinh doanh trước'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% so với ngày kinh doanh trước';
    return ForeCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Doanh thu hôm nay', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(formatVnd(data.totalSales), style: AppTextStyles.display),
        const SizedBox(height: 6),
        Text(
          'Tiền mặt ${formatVnd(data.cashSales)} · Chuyển khoản ${formatVnd(data.transferSales)}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 4),
        Text(changeLabel, style: AppTextStyles.captionStrong),
      ]),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.hasUnread});
  final bool hasUnread;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            'assets/owner_dashboard/file1/bell.svg',
            width: 22,
            height: 22,
          ),
          if (hasUnread)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.statusOff,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      );
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
        action: TextButton(
          onPressed: onOpenOps,
          child: Text(shift == null ? 'Mở ca' : 'Vào vận hành'),
        ),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final OwnerShiftReport report;
  final VoidCallback onTap;

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
        : '${primary['ingredient_name']}: +${primary['adjusted_variance']} ${primary['unit']}'
            '${primary['equiv_revenue'] == null ? '' : ' · ~${formatVnd(_number(primary['equiv_revenue']))}'}';
    final openedBy = report.shift['opened_by_name'] ?? 'Nhân viên';
    final handledText = report.handled ? 'Đã xử lý' : 'Chưa xử lý';
    return _InfoCard(
      icon: status == 'alert'
          ? Icons.error_outline
          : status == 'warn'
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
      title: _shiftLabel(report.shift),
      body:
          '$openedBy · ${_statusText(status)} · Tiền mặt ${formatVnd(variance)} · $handledText\n$summary',
      action: TextButton(onPressed: onTap, child: const Text('Xem chi tiết')),
    );
  }
}

class _CashResultCard extends StatelessWidget {
  const _CashResultCard({required this.cash, required this.variance});
  final Map<String, dynamic> cash;
  final int variance;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tiền mặt cuối ca',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              '${variance < 0 ? 'Thiếu' : variance > 0 ? 'Thừa' : 'Khớp'} ${formatVnd(variance.abs())}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _whiteRow('Kỳ vọng cuối ca', _number(cash['expected_cash'])),
            _whiteRow('Thực đếm cuối ca', _number(cash['closing_cash'])),
          ]),
        ),
      );

  Widget _whiteRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.white70))),
          Text(formatVnd(value),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _ReviewEditor extends StatefulWidget {
  const _ReviewEditor({required this.report, required this.onSave});
  final OwnerShiftReport report;
  final Future<bool> Function(bool handled, String? note) onSave;

  @override
  State<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<_ReviewEditor> {
  late final _note = TextEditingController(text: widget.report.note);
  late bool _handled = widget.report.handled;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _ReviewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report) {
      _note.text = widget.report.note;
      _handled = widget.report.handled;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(bool handled) async {
    setState(() => _busy = true);
    try {
      final saved = await widget.onSave(handled, _note.text.trim());
      if (saved && mounted) setState(() => _handled = handled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trạng thái xử lý: ${_handled ? 'Đã xử lý' : 'Chưa xử lý'}',
              style: AppTextStyles.title),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ghi chú kiểm tra',
              hintText: 'Ví dụ: Đã đối chiếu số đếm và chứng từ thu chi.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _save(_handled),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu ghi chú'),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy ? null : () => _save(!_handled),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_handled ? Icons.undo_rounded : Icons.check_rounded),
            label: Text(_handled ? 'Đánh dấu chưa xử lý' : 'Đánh dấu đã xử lý'),
          ),
        ]),
      );
}

class _KeyValueCard extends StatelessWidget {
  const _KeyValueCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(label, style: AppTextStyles.body)),
                  Text(value, style: AppTextStyles.title),
                ]),
              ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.brandAccent),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headline),
          Text(label, style: AppTextStyles.caption),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = ForeCard(
      padding: const EdgeInsets.all(15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.brandAccent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(body, style: AppTextStyles.caption),
            if (action != null) ...[
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: action!),
            ],
          ]),
        ),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: child,
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ForeCard(
          child: ListTile(
            enabled: enabled,
            leading: Icon(icon, color: AppColors.brandAccent),
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: enabled ? onTap : null,
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTextStyles.headline)),
          if (trailing != null) trailing!,
        ]),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry, this.message});
  final Future<void> Function() onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppColors.warning),
            const SizedBox(height: 12),
            const Text('Chưa thể cập nhật', style: AppTextStyles.headline),
            const SizedBox(height: 6),
            Text(
              message ??
                  'Không tải được dữ liệu quán. Hãy kiểm tra kết nối và cấu hình database.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
      );
}

String _businessDayLabel(OwnerDashboardData data) =>
    'Ngày kinh doanh: ${formatHm(data.businessStart)} · ${data.businessStart.day}/${data.businessStart.month} – 05:59 hôm sau';

String _minimumStock(Map<String, dynamic> ingredient, OwnerDashboardData data) {
  final matching = data.lowStock.where(
    (item) => item['ingredient_id'] == ingredient['ingredient_id'],
  );
  if (matching.isEmpty) return '';
  final threshold = matching.first['minimum_qty'];
  return ' · Dưới ngưỡng $threshold ${ingredient['unit'] ?? ''}';
}

String _shiftLabel(Map<String, dynamic> shift) {
  final opened = DateTime.tryParse('${shift['opened_at']}')?.toLocal();
  if (opened == null) return 'Ca đã đóng';
  final closed = DateTime.tryParse('${shift['closed_at']}')?.toLocal();
  final day = '${opened.day}/${opened.month}';
  return 'Ca $day · ${formatHm(opened)}${closed == null ? '' : '–${formatHm(closed)}'}';
}

String _statusText(String status) => switch (status) {
      'alert' => 'Lệch lớn',
      'warn' => 'Cần kiểm tra',
      'ok' => 'Ổn',
      _ => 'Chưa đủ dữ liệu',
    };

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
