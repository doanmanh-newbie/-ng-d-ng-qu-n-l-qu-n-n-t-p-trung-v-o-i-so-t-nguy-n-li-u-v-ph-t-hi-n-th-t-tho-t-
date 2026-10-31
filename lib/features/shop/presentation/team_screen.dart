import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/phone.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fore_button.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/team_controller.dart';
import '../domain/shop_models.dart';
import 'invite_list.dart' show timeAgo;

/// Chủ quán: nhân viên của quán và nút "Thêm nhân viên" bằng số điện thoại.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  Future<void> _openInvite(BuildContext context) async {
    final controller = context.read<TeamController>();
    controller.clearFormErrors();
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const _InviteSheet(),
      ),
    );
    if (sent != null) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Đã mời $sent. Họ sẽ nhận thông báo trong ứng dụng.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TeamController>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Nhân viên', style: AppTextStyles.heading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => _openInvite(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Thêm nhân viên'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => c.load(quiet: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (c.loading && c.members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (c.error != null && c.members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(c.error!,
                    textAlign: TextAlign.center, style: AppTextStyles.body),
              )
            else ...[
              if (c.pending.isNotEmpty) ...[
                const _SectionTitle('Đang chờ chấp nhận'),
                for (final p in c.pending)
                  FadeSlideIn(
                    key: ValueKey(p.id),
                    child: _PendingTile(invite: p),
                  ),
                const SizedBox(height: 16),
              ],
              const _SectionTitle('Thành viên'),
              for (var i = 0; i < c.members.length; i++)
                FadeSlideIn(
                  key: ValueKey(c.members[i].staffId),
                  delay: Duration(milliseconds: 50 * i),
                  child: _MemberTile(member: c.members[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.muted = false});

  final String name;
  final bool muted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: muted ? AppColors.disabledFill : AppColors.tint,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Text(
              name.isEmpty
                  ? '?'
                  : String.fromCharCode(name.runes.first).toUpperCase(),
              style: AppTextStyles.heading.copyWith(fontSize: 18),
            ),
          ),
        ),
      );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final contact =
        member.phone.isNotEmpty ? Phone.pretty(member.phone) : member.email;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ForeCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Avatar(member.fullName, muted: !member.active),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 15,
                      color: member.active
                          ? AppColors.textPrimary
                          : AppColors.inkMuted,
                    ),
                  ),
                  if (contact.isNotEmpty)
                    Text(contact, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (member.isOwner)
              const _Chip('Chủ quán')
            else if (!member.active)
              const _Chip('Đã nghỉ'),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(text, style: AppTextStyles.caption),
        ),
      );
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.invite});

  final PendingInvite invite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ForeCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(Icons.hourglass_top_rounded,
                    color: AppColors.warningText, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invite.fullName,
                      style: AppTextStyles.label.copyWith(fontSize: 15)),
                  Text(
                    [
                      if (invite.phone != null)
                        Phone.pretty('+${invite.phone}'),
                      if (invite.email != null) invite.email,
                      timeAgo(invite.createdAt)
                    ].join(' · '),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hủy lời mời',
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final err = await context.read<TeamController>().cancel(invite);
                if (err != null) {
                  messenger.showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = context.read<TeamController>();
    final navigator = Navigator.of(context);
    final ok = await c.invite(
      phone: _phone.text,
      fullName: _name.text,
      email: _email.text,
    );
    if (ok && mounted) navigator.pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TeamController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Thêm nhân viên', style: AppTextStyles.heading),
            const SizedBox(height: 4),
            const Text(
              'Điền số điện thoại, email hoặc cả hai. Nhân viên cần xác minh thông tin tương ứng để nhận lời mời trong hộp thư.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Số điện thoại (không bắt buộc)',
              controller: _phone,
              hint: '0901 234 567',
              errorText: c.phoneError,
              enabled: !c.inviting,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Email (không bắt buộc)',
              controller: _email,
              hint: 'name@example.com',
              errorText: c.emailError,
              enabled: !c.inviting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Tên hiển thị',
              controller: _name,
              hint: 'Ví dụ: Lan',
              errorText: c.nameError,
              enabled: !c.inviting,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (c.formError != null) ...[
              const SizedBox(height: 8),
              Text(c.formError!,
                  style: const TextStyle(
                      color: AppColors.statusOff, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            LoadingButton(
              label: 'Gửi lời mời',
              loadingLabel: 'Đang gửi',
              loading: c.inviting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
