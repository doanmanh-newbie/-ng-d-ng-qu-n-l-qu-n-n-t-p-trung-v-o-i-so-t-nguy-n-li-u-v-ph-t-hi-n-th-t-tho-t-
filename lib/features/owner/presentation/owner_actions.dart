part of 'owner_home_screen.dart';

extension _OwnerActions on _OwnerHomeContentState {
  Widget _more(OwnerDashboardData data) {
    return MoreView(
      header: _pageHeader(),
      personName: widget.profile.fullName,
      roleLabel: 'Chủ quán',
      shopName: widget.profile.shopName,
      hasOpenShift: data.openShift != null,
      isOwner: true,
      onWaste: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WasteScreen(
            repository: context.read<InventoryRepository>(),
          ),
        ),
      ),
      onCash: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CashScreen(
            repository: context.read<CashRepository>(),
          ),
        ),
      ),
      onSwitchShop: () => showShopSwitcher(context),
      onInbox: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
      onTeam: () => Navigator.of(context).pushNamed(AppRoutes.team),
      onSignOut: _signOut,
    );
  }

  Future<void> _openMenuManagement() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChangeNotifierProvider(
          create: (context) => OwnerMenuController(
            context.read<OwnerMenuRepository>(),
          )..load(),
          child: const OwnerMenuManagementScreen(),
        ),
      ),
    );
    if (changed == true && mounted) await _refresh();
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
      await context.read<OwnerDashboardController>().saveReview(
            report,
            handled,
            note,
          );
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Không lưu được trạng thái đối soát. Vui lòng thử lại.'),
          ),
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
          onMarkRead:
              context.read<OwnerDashboardController>().markNotificationsRead,
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
      _updateState(() {
        _tab = 1;
        _selectedReport = result;
      });
    }
  }
}
