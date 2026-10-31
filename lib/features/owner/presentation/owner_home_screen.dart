import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../app/app_routes.dart';
import '../../../core/format.dart';
import '../../../core/design/app_header.dart';
import '../../../core/design/hero_card.dart';
import '../../../core/design/skeleton_box.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/fore_action_icons.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../home/home_screen.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/presentation/cash_screen.dart';
import '../../inventory/presentation/waste_screen.dart';
import '../../more/more_view.dart';
import '../../shop/presentation/shop_switcher.dart';
import '../application/owner_menu_controller.dart';
import '../data/owner_dashboard_repository.dart';
import '../application/owner_dashboard_controller.dart';
import '../domain/owner_dashboard_models.dart';
import '../domain/owner_menu_repository.dart';
import 'owner_notifications_screen.dart';
import 'owner_menu_management_screen.dart';

part 'owner_dashboard_widgets.dart';
part 'owner_dashboard_report_widgets.dart';
part 'owner_dashboard_review_widgets.dart';
part 'owner_dashboard_loading_widgets.dart';
part 'owner_dashboard_formatters.dart';
part 'owner_overview.dart';
part 'owner_reconciliation.dart';
part 'owner_catalog.dart';
part 'owner_actions.dart';

/// Trang chủ riêng của chủ quán. Số liệu mẫu trong file thiết kế không được dùng
/// ở đây; mọi chỉ số hiển thị đều lấy từ database hoặc hiện trạng thái trống/lỗi.
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) =>
            OwnerDashboardController(context.read<OwnerDashboardDataSource>())
              ..load(),
        child: _OwnerHomeContent(profile: profile),
      );
}

class _OwnerHomeContent extends StatefulWidget {
  const _OwnerHomeContent({required this.profile});

  final Profile profile;

  @override
  State<_OwnerHomeContent> createState() => _OwnerHomeContentState();
}

class _OwnerHomeContentState extends State<_OwnerHomeContent> {
  int _tab = 0;
  OwnerShiftReport? _selectedReport;

  void _updateState(VoidCallback update) => setState(update);

  Future<void> _refresh() =>
      context.read<OwnerDashboardController>().load(refresh: true);

  Widget _pageHeader() {
    final data = context.watch<OwnerDashboardController>().data;
    return AppHeader(
      shopName:
          widget.profile.shopName.isEmpty ? 'Fore' : widget.profile.shopName,
      subtitle: 'Chủ quán · ${widget.profile.fullName}',
      onChooseShop: () => showShopSwitcher(context),
      onNotifications: data == null ? null : () => _openNotifications(data),
      unreadCount:
          data?.notifications.where((notice) => !notice.read).length ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<OwnerDashboardController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (context) {
          final data = dashboard.data;
          if (data == null && dashboard.loading) {
            return const _OwnerDashboardLoading();
          }
          if (data == null) {
            return _ErrorPanel(
              onRetry: _refresh,
              message: _errorMessage(dashboard.failure),
            );
          }
          final page = _page(data);
          if (dashboard.failure == null) return page;
          return Column(children: [
            MaterialBanner(
              content: Text(_errorMessage(dashboard.failure)),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
            ),
            Expanded(child: page),
          ]);
        },
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
  }

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
}
