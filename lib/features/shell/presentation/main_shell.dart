import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/fore_icon.dart';
import '../../home/home_tab.dart';
import '../../shift/application/shift_controller.dart';
import '../../shop/application/inbox_controller.dart';
import '../../shop/domain/shop_repository.dart';
import 'close_shift_tab.dart';
import 'coming_soon_tab.dart';
import 'fore_bottom_nav.dart';
import 'more_tab.dart';

/// Khung chính của nhân viên: năm tab và thanh tab dưới cùng.
///
/// Giữ nguyên tab đang xem khi chuyển qua lại (IndexedStack). Hỏi lại trạng thái
/// ca mỗi khi app được mở lại từ nền, vì có thể người khác đã mở hoặc đóng ca.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final InboxController _inbox = InboxController(context.read<ShopRepository>());
  ShellTab _tab = ShellTab.home;
  ShellTab? _shakeTab;
  int _shakeTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShiftController>().load();
    });
    _inbox
      ..load(quiet: true)
      ..startPolling(const Duration(seconds: 60));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inbox.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ShiftController>().load(quiet: true);
      _inbox.load(quiet: true);
    }
  }

  void _onLockedTap(ShellTab tab) {
    setState(() {
      _shakeTab = tab;
      _shakeTick++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Mở ca để dùng ${tab.label}.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final shiftOpen = context.select<ShiftController, bool>(
      (c) => c.state is ShiftOpen,
    );

    // Ca bị đóng ở nơi khác trong lúc đang xem tab cần ca: quay về Trang chủ.
    if (!shiftOpen && _tab.requiresShift) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = ShellTab.home);
      });
    }

    return ChangeNotifierProvider<InboxController>.value(
      value: _inbox,
      child: Scaffold(
      body: IndexedStack(
        index: ShellTab.values.indexOf(_tab),
        children: [
          const ComingSoonTab(
            icon: ForeIcon.bag,
            title: 'Mang đi',
            message: 'Đơn mang đi đang được làm ở bước sau.',
          ),
          const ComingSoonTab(
            icon: ForeIcon.package,
            title: 'Kho',
            message: 'Nhập hàng và đếm kho đang được làm ở bước sau.',
          ),
          const HomeTab(),
          const CloseShiftTab(),
          const MoreTab(),
        ],
      ),
      bottomNavigationBar: ForeBottomNav(
        current: _tab,
        shiftOpen: shiftOpen,
        shakeTab: _shakeTab,
        shakeTick: _shakeTick,
        onSelect: (tab) => setState(() => _tab = tab),
        onLockedTap: _onLockedTap,
      ),
    ),
    );
  }
}
