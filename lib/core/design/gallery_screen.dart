import 'package:flutter/material.dart';

import '../widgets/fore_card.dart' show ForeCard;
import '../widgets/status_chip.dart';
import 'action_tile.dart';
import 'app_form_field.dart';
import 'app_header.dart';
import 'app_sheet.dart';
import 'attention_item.dart';
import 'bottom_nav.dart';
import 'colors.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'hero_card.dart';
import 'kpi_card.dart';
import 'list_row.dart';
import 'page_title_block.dart';
import 'section_header.dart';
import 'skeleton_box.dart';
import 'spacing.dart';
import 'stat_tile.dart';
import 'severity_chip.dart';
import 'status_pill.dart';
import 'tertiary_button.dart';
import 'typography.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

void _noop() {}

/// Gallery chỉ bật ở debug để kiểm tra component và cỡ chữ trên thiết bị.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: const [
            AppHeader(
              shopName: 'Fore · Tên quán mẫu rất dài để thử dấu ba chấm',
              unreadCount: 2,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                12,
                AppSizes.pagePadding,
                AppSizes.pageBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageTitleBlock(
                    title: 'Thư viện giao diện',
                    today: 'Hôm nay, 28/10',
                    updatedAt: 'Cập nhật lúc 07:12',
                    businessDay: 'Ngày kinh doanh: 06:00 đến 05:59 hôm sau',
                  ),
                  SizedBox(height: 12),
                  SectionHeader(title: 'Màu và kiểu chữ'),
                  SizedBox(height: 8),
                  _ColorSamples(),
                  SizedBox(height: 16),
                  SectionHeader(title: 'Trạng thái'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                          label: 'Trong ngưỡng',
                          severity: StatusSeverity.healthy),
                      StatusPill(
                          label: 'Cần chú ý',
                          severity: StatusSeverity.attention),
                      StatusPill(
                          label: 'Lệch lớn', severity: StatusSeverity.critical),
                      StatusPill(
                          label: 'Đang chờ', severity: StatusSeverity.neutral),
                    ],
                  ),
                  SizedBox(height: 16),
                  SectionHeader(title: 'Chỉ số và hành động'),
                  SizedBox(height: 8),
                  KpiCard(
                    label: 'Doanh thu hôm nay',
                    value: '8.518.000đ',
                    comparison: 'Đến 19:12 · cùng khung giờ',
                    footer: 'Tiền mặt 5.696.000đ · Chuyển khoản 2.822.000đ',
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: StatTile(
                              label: 'Bill đã thanh toán', value: '193')),
                      SizedBox(width: 8),
                      Expanded(
                          child: StatTile(
                              label: 'Doanh thu / bill', value: '44.134đ')),
                    ],
                  ),
                  SizedBox(height: 8),
                  HeroCard(
                    title: 'Ca 28/10 · Minh Anh · Ca sáng',
                    status: SeverityChip(
                      label: 'Lệch lớn',
                      severity: StatusSeverity.critical,
                    ),
                    primaryLabel: 'Xem chi tiết đối soát',
                    secondaryLabel: 'Ghi chú',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thiếu 120.000đ'),
                        SizedBox(height: 4),
                        Text(
                            'Kiểm tra dòng tiền và ghi chú trước khi đánh dấu xử lý.'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  SectionHeader(title: 'Danh sách và cần chú ý'),
                  SizedBox(height: 8),
                  ActionTile(
                    icon: Icon(Icons.people_outline),
                    title: 'Mời nhân viên',
                    subtitle: 'Thêm người vào quán',
                    onTap: null,
                  ),
                  SizedBox(height: 8),
                  AttentionItem(
                    icon: Icons.warning_amber_rounded,
                    title: '2 nguyên liệu dưới ngưỡng',
                    message: 'Kiểm tra tồn kho trước ca tiếp theo.',
                    actionLabel: 'Mở kho',
                  ),
                  SizedBox(height: 8),
                  ForeCard(
                    padding: EdgeInsets.zero,
                    child: ListRow(
                      title: 'Ca 28/10 · Minh Anh · Ca sáng',
                      subtitle: 'Đã đóng lúc 22:04 · Chưa xử lý',
                      leading: Icon(Icons.receipt_long_outlined),
                      trailing: Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  SizedBox(height: 16),
                  SectionHeader(title: 'Nút và trạng thái tải'),
                  SizedBox(height: 8),
                  PrimaryButton(label: 'Lưu thay đổi', onPressed: null),
                  SizedBox(height: 8),
                  SecondaryButton(label: 'Hủy', onPressed: null),
                  SizedBox(height: 8),
                  TertiaryButton(label: 'Xem tất cả', onPressed: _noop),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 72)),
                      SizedBox(width: 8),
                      Expanded(child: SkeletonBox(height: 72)),
                    ],
                  ),
                  SizedBox(height: 12),
                  ForeCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Chưa có dữ liệu',
                      message:
                          'Nội dung sẽ xuất hiện sau khi quán có ca đầu tiên.',
                    ),
                  ),
                  SizedBox(height: 12),
                  ForeCard(
                    child: ErrorState(
                      message: 'Kiểm tra kết nối rồi thử lại.',
                      onRetry: _noop,
                    ),
                  ),
                  SizedBox(height: 12),
                  AppFormFieldSample(),
                  SizedBox(height: 12),
                  ForeCard(
                    padding: EdgeInsets.zero,
                    child: AppSheet(
                      title: 'Ghi chú ca',
                      child: Text('Nội dung sheet và khoảng đệm an toàn.'),
                    ),
                  ),
                  SizedBox(height: 12),
                  BottomNavSample(),
                  SizedBox(height: 12),
                  Text('Số tiền dùng chữ số thẳng hàng',
                      style: AppTextStyles.caption),
                  SizedBox(height: 4),
                  Text('−120.000đ · 4.670 ml · 2,16 kg',
                      style: AppTextStyles.metric),
                ],
              ),
            ),
          ],
        ),
      );
}

class AppFormFieldSample extends StatefulWidget {
  const AppFormFieldSample({super.key});

  @override
  State<AppFormFieldSample> createState() => _AppFormFieldSampleState();
}

class _AppFormFieldSampleState extends State<AppFormFieldSample> {
  final _controller = TextEditingController(text: 'Ghi chú của ca');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ForeCard(
        child: AppFormField(
          label: 'Trường nhập dùng chung',
          controller: _controller,
          hint: 'Nhập nội dung',
        ),
      );
}

class BottomNavSample extends StatelessWidget {
  const BottomNavSample({super.key});

  @override
  Widget build(BuildContext context) => const BottomNav(
        items: [
          NavItem(label: 'Tổng quan', icon: 'assets/icons/home.svg'),
          NavItem(label: 'Đối soát', icon: 'assets/icons/package.svg'),
          NavItem(label: 'Thêm', icon: 'assets/icons/plus.svg'),
        ],
        selected: 0,
        onSelect: _ignoreSelection,
      );

  static void _ignoreSelection(int _) {}
}

class _ColorSamples extends StatelessWidget {
  const _ColorSamples();

  @override
  Widget build(BuildContext context) {
    const samples = <(String, Color)>[
      ('Mực', AppColors.brand),
      ('Teal', AppColors.brandAccent),
      ('Nền', AppColors.background),
      ('Xanh · ổn', AppColors.statusHealthy),
      ('Vàng · chú ý', AppColors.statusAttention),
      ('Đỏ · lệch', AppColors.statusCritical),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, color) in samples)
          Container(
            width: 100,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.micro.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
