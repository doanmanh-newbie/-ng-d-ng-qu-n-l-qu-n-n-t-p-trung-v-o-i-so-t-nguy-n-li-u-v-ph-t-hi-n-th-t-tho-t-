part of 'owner_home_screen.dart';

extension _OwnerCatalog on _OwnerHomeContentState {
  Widget _menu(OwnerDashboardData data) => PageScaffold(
        header: _pageHeader(),
        children: [
          Row(children: [
            const Expanded(
                child: Text('Thực đơn', style: AppTextStyles.display)),
            FilledButton.tonalIcon(
              onPressed: () => _openMenuManagement(),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Quản lý'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ]),
          const SizedBox(height: 8),
          if (data.missingRecipeCount > 0) ...[
            _InfoCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.statusAttention,
              title: '${data.missingRecipeCount} size thiếu công thức',
              status: const StatusChip(
                label: 'Cần bổ sung',
                severity: StatusSeverity.attention,
                compact: true,
              ),
              body: 'Hoàn thiện công thức để đối soát nguyên liệu chính xác.',
              onTap: _openMenuManagement,
              showArrow: true,
            ),
            const SizedBox(height: 4),
          ],
          if (data.menu.isEmpty)
            const _InfoCard(
              icon: Icons.menu_book_outlined,
              iconColor: AppColors.textSecondary,
              title: 'Chưa có món đang bán',
              status: StatusChip(
                label: 'Chưa có dữ liệu',
                severity: StatusSeverity.neutral,
                compact: true,
              ),
              body: 'Thêm món và size để bắt đầu nhận đơn.',
            )
          else
            ...data.menu.map((row) => _InfoCard(
                  icon: Icons.local_cafe_outlined,
                  title: '${row['item_name']} · ${row['size_name']}',
                  status: row['has_recipe'] == true
                      ? null
                      : const StatusChip(
                          label: 'Thiếu công thức',
                          severity: StatusSeverity.attention,
                          compact: true,
                        ),
                  body: formatVnd(_number(row['price'])),
                  onTap: _openMenuManagement,
                  showArrow: true,
                )),
        ],
      );

  Widget _stock(OwnerDashboardData data) => PageScaffold(
        header: _pageHeader(),
        children: [
          const Text('Kho', style: AppTextStyles.display),
          const SizedBox(height: 12),
          if (data.expectedStock.isEmpty)
            const _InfoCard(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.textSecondary,
              title: 'Chưa có số liệu tồn kho',
              status: StatusChip(
                label: 'Chưa có dữ liệu',
                severity: StatusSeverity.neutral,
                compact: true,
              ),
              body: 'Tồn dự kiến sẽ xuất hiện sau khi có kiểm kê.',
            )
          else
            ..._stockRowsBySeverity(data).map((row) => _InfoCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: row['expected_qty'] == null
                      ? AppColors.textSecondary
                      : _stockSeverity(_number(row['expected_qty'])) ==
                              StatusSeverity.critical
                          ? AppColors.statusOff
                          : _isBelowThreshold(row, data)
                              ? AppColors.statusWatch
                              : AppColors.statusOk,
                  title: '${row['name'] ?? 'Nguyên liệu'}',
                  status: row['expected_qty'] == null
                      ? const StatusChip(
                          label: 'Chưa có số liệu',
                          severity: StatusSeverity.neutral,
                          compact: true,
                        )
                      : StatusChip(
                          label: _stockStatusLabel(row, data),
                          severity: _stockSeverity(
                            _number(row['expected_qty']),
                            belowThreshold: _isBelowThreshold(row, data),
                          ),
                          compact: true,
                        ),
                  body: row['expected_qty'] == null
                      ? 'Chưa có lần kiểm kê · ${row['unit'] ?? ''}'
                      : _number(row['expected_qty']) < 0
                          ? 'Tồn dự kiến âm '
                              '${formatQuantity(_number(row['expected_qty']).abs(), unit: '${row['unit'] ?? ''}')}. Cần kiểm tra kiểm kê và hao hụt.'
                          : 'Tồn dự kiến ${formatQuantity(_number(row['expected_qty']), unit: '${row['unit'] ?? ''}')}'
                              '${_minimumStock(row, data)}',
                )),
          const SizedBox(height: 12),
          const _SectionTitle(title: 'Thao tác kho'),
          Row(children: [
            Expanded(
              child: _StockActionButton(
                title: 'Ghi hao hụt',
                icon: ForeActionIcons.waste,
                enabled: data.openShift != null,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => WasteScreen(
                      repository: context.read<InventoryRepository>(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StockActionButton(
                title: 'Thu / chi',
                icon: ForeActionIcons.cashMovement,
                enabled: data.openShift != null,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CashScreen(
                      repository: context.read<CashRepository>(),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      );
}
