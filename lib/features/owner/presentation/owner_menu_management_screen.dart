import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_chip.dart';

/// Owner-only menu editor. Rows are hidden through active=false; historical
/// menu and bill data is never physically deleted.
class OwnerMenuManagementScreen extends StatefulWidget {
  const OwnerMenuManagementScreen({super.key});

  @override
  State<OwnerMenuManagementScreen> createState() =>
      _OwnerMenuManagementScreenState();
}

class _OwnerMenuManagementScreenState extends State<OwnerMenuManagementScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _ingredients = const [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('menu_items')
            .select('id,name,group_name,active')
            .order('name'),
        _client
            .from('menu_sizes')
            .select('id,item_id,size_name,price,active')
            .order('size_name'),
        _client.from('recipe_lines').select('id,size_id,ingredient_id,qty'),
        _client.from('ingredients').select('id,name,unit,active').order('name'),
      ]);
      if (!mounted) return;
      final sizes = (results[1] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final lines = (results[2] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final ingredientRows = (results[3] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final activeIngredients =
          ingredientRows.where((row) => row['active'] == true).toList();
      final ingredientsById = {
        for (final row in ingredientRows) '${row['id']}': row,
      };
      for (final line in lines) {
        line['ingredients'] = ingredientsById['${line['ingredient_id']}'];
      }
      for (final size in sizes) {
        size['recipe_lines'] =
            lines.where((line) => line['size_id'] == size['id']).toList();
      }
      final items = (results[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      for (final item in items) {
        item['menu_sizes'] =
            sizes.where((size) => size['item_id'] == item['id']).toList();
      }
      setState(() {
        _items = items;
        _ingredients = activeIngredients;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _addItem() async {
    final values = await _itemDialog();
    if (values == null) return;
    try {
      final item = await _client
          .from('menu_items')
          .insert({
            'name': values.name,
            'group_name': values.group.isEmpty ? null : values.group,
          })
          .select('id')
          .single();
      await _client.from('menu_sizes').insert({
        'item_id': item['id'],
        'size_name': values.size,
        'price': values.price,
      });
      _changed = true;
      await _load();
      _message('Đã thêm món và size ${values.size}.');
    } catch (error) {
      await _load();
      _message(_friendlyError(error));
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final values = await _itemDialog(item: item);
    if (values == null) return;
    try {
      await _client.from('menu_items').update({
        'name': values.name,
        'group_name': values.group.isEmpty ? null : values.group,
      }).eq('id', item['id']);
      _changed = true;
      await _load();
      _message('Đã lưu thay đổi món.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<_MenuItemInput?> _itemDialog({Map<String, dynamic>? item}) async {
    final name = TextEditingController(text: '${item?['name'] ?? ''}');
    final group = TextEditingController(text: '${item?['group_name'] ?? ''}');
    final size = TextEditingController(text: 'M');
    final price = TextEditingController();
    final result = await showDialog<_MenuItemInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Thêm món' : 'Sửa món'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Tên món'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: group,
              decoration:
                  const InputDecoration(labelText: 'Nhóm món (không bắt buộc)'),
            ),
            if (item == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: size,
                decoration: const InputDecoration(labelText: 'Size đầu tiên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá bán (đ)'),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final parsedPrice = int.tryParse(
                  price.text.replaceAll('.', '').replaceAll(',', '').trim());
              if (name.text.trim().isEmpty ||
                  (item == null &&
                      (size.text.trim().isEmpty ||
                          parsedPrice == null ||
                          parsedPrice < 0))) {
                return;
              }
              Navigator.pop(
                context,
                _MenuItemInput(
                  name: name.text.trim(),
                  group: group.text.trim(),
                  size: size.text.trim(),
                  price: parsedPrice ?? 0,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    name.dispose();
    group.dispose();
    size.dispose();
    price.dispose();
    return result;
  }

  Future<void> _addSize(Map<String, dynamic> item) async {
    final size = TextEditingController();
    final price = TextEditingController();
    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm size · ${item['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: size,
              decoration: const InputDecoration(labelText: 'Tên size')),
          const SizedBox(height: 12),
          TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá bán (đ)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(
                  price.text.replaceAll('.', '').replaceAll(',', '').trim());
              if (size.text.trim().isNotEmpty &&
                  parsed != null &&
                  parsed >= 0) {
                Navigator.pop(context, (size.text.trim(), parsed));
              }
            },
            child: const Text('Thêm size'),
          ),
        ],
      ),
    );
    size.dispose();
    price.dispose();
    if (result == null) return;
    try {
      await _client.from('menu_sizes').insert({
        'item_id': item['id'],
        'size_name': result.$1,
        'price': result.$2,
      });
      _changed = true;
      await _load();
      _message('Đã thêm size ${result.$1}.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _editSize(Map<String, dynamic> size) async {
    final name = TextEditingController(text: '${size['size_name']}');
    final price = TextEditingController(text: '${size['price']}');
    final values = await showDialog<(String, int)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa size và giá'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên size')),
          const SizedBox(height: 12),
          TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá bán (đ)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(
                  price.text.replaceAll('.', '').replaceAll(',', '').trim());
              if (name.text.trim().isNotEmpty &&
                  parsed != null &&
                  parsed >= 0) {
                Navigator.pop(context, (name.text.trim(), parsed));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    name.dispose();
    price.dispose();
    if (values == null) return;
    try {
      await _client.from('menu_sizes').update({
        'size_name': values.$1,
        'price': values.$2,
      }).eq('id', size['id']);
      _changed = true;
      await _load();
      _message('Đã cập nhật size.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _setActive(String table, String id, bool active) async {
    try {
      await _client.from(table).update({'active': active}).eq('id', id);
      _changed = true;
      await _load();
      _message(active ? 'Đã bật bán lại.' : 'Đã ẩn khỏi thực đơn bán.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _addRecipeLine(Map<String, dynamic> size) async {
    if (_ingredients.isEmpty) {
      _message('Hãy tạo nguyên liệu trong Kho trước khi thêm công thức.');
      return;
    }
    String? ingredientId = '${_ingredients.first['id']}';
    final quantity = TextEditingController();
    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Thêm nguyên liệu · size ${size['size_name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: ingredientId,
              decoration: const InputDecoration(labelText: 'Nguyên liệu'),
              items: _ingredients
                  .map((ingredient) => DropdownMenuItem(
                        value: '${ingredient['id']}',
                        child: Text(
                            '${ingredient['name']} · ${ingredient['unit']}'),
                      ))
                  .toList(),
              onChanged: (value) => setDialogState(() => ingredientId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Định lượng cho một ly'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(quantity.text.trim());
                if (ingredientId != null && qty != null && qty > 0) {
                  Navigator.pop(context, (ingredientId!, qty));
                }
              },
              child: const Text('Thêm vào công thức'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    if (result == null) return;
    try {
      await _client.from('recipe_lines').insert({
        'size_id': size['id'],
        'ingredient_id': result.$1,
        'qty': result.$2,
      });
      _changed = true;
      await _load();
      _message('Đã thêm nguyên liệu vào công thức.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _changeRecipeQuantity(Map<String, dynamic> line) async {
    final quantity = TextEditingController(text: '${line['qty']}');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Định lượng · ${line['ingredients']?['name'] ?? 'nguyên liệu'}'),
        content: TextField(
          controller: quantity,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Số lượng (${line['ingredients']?['unit'] ?? ''})',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(quantity.text.trim());
              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    quantity.dispose();
    if (result == null) return;
    try {
      await _client
          .from('recipe_lines')
          .update({'qty': result}).eq('id', line['id']);
      _changed = true;
      await _load();
      _message('Đã cập nhật định lượng.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<void> _confirmRemoveRecipeLine(Map<String, dynamic> line) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ khỏi công thức?'),
        content: Text(
            'Bỏ ${line['ingredients']?['name'] ?? 'nguyên liệu'} khỏi size này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giữ lại')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ khỏi công thức')),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await _client.from('recipe_lines').delete().eq('id', line['id']);
      _changed = true;
      await _load();
      _message('Đã cập nhật công thức.');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Quản lý thực đơn'),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : PageScaffold(children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Món đang bán',
                              style: AppTextStyles.display)),
                      FilledButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm món'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      const _MenuMessage(
                        title: 'Chưa có món nào',
                        body: 'Thêm món và size đầu tiên để bắt đầu nhận đơn.',
                      )
                    else
                      ..._items.map(_itemCard),
                    const SizedBox(height: 8),
                    const Text(
                      'Món và size được ẩn khi ngừng bán; dữ liệu đã dùng trong bill vẫn được giữ lại.',
                      style: AppTextStyles.caption,
                    ),
                  ]),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.statusCritical),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center, style: AppTextStyles.body),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại')),
          ]),
        ),
      );

  Widget _itemCard(Map<String, dynamic> item) {
    final sizes = (item['menu_sizes'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
      ..sort((a, b) => '${a['size_name']}'.compareTo('${b['size_name']}'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${item['name']}', style: AppTextStyles.title)),
            if (item['active'] != true)
              const StatusChip(
                  label: 'Đang ẩn',
                  severity: StatusSeverity.neutral,
                  compact: true),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn món',
              onSelected: (value) {
                if (value == 'edit') _editItem(item);
                if (value == 'active') {
                  _setActive(
                      'menu_items', '${item['id']}', item['active'] != true);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Sửa tên / nhóm')),
                PopupMenuItem(
                  value: 'active',
                  child:
                      Text(item['active'] == true ? 'Ẩn món' : 'Bật bán lại'),
                ),
              ],
            ),
          ]),
          if ('${item['group_name'] ?? ''}'.isNotEmpty)
            Text('${item['group_name']}', style: AppTextStyles.caption),
          const Divider(height: 20),
          if (sizes.isEmpty)
            const _MenuMessage(
                title: 'Món chưa có size',
                body: 'Thêm size và giá để món có thể được bán.'),
          for (final size in sizes) _sizeCard(size),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addSize(item),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm size'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sizeCard(Map<String, dynamic> size) {
    final lines = (size['recipe_lines'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
                '${size['size_name']} · ${formatVnd((size['price'] as num?)?.toInt() ?? 0)}',
                style: AppTextStyles.bodyStrong),
          ),
          if (size['active'] != true)
            const StatusChip(
                label: 'Đang ẩn',
                severity: StatusSeverity.neutral,
                compact: true),
          IconButton(
            tooltip: 'Sửa size và giá',
            visualDensity: VisualDensity.compact,
            onPressed: () => _editSize(size),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          IconButton(
            tooltip: size['active'] == true ? 'Ẩn size' : 'Bật bán size',
            visualDensity: VisualDensity.compact,
            onPressed: () => _setActive(
                'menu_sizes', '${size['id']}', size['active'] != true),
            icon: Icon(
                size['active'] == true
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19),
          ),
        ]),
        if (lines.isEmpty)
          Row(children: [
            const StatusChip(
                label: 'Thiếu công thức',
                severity: StatusSeverity.attention,
                compact: true),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _addRecipeLine(size),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm nguyên liệu'),
            ),
          ])
        else ...[
          for (final line in lines)
            Row(children: [
              Expanded(
                child: Text(
                  '${line['ingredients']?['name'] ?? 'Nguyên liệu'} · ${formatQuantity((line['qty'] as num?)?.toInt() ?? 0, unit: '${line['ingredients']?['unit'] ?? ''}')}',
                  style: AppTextStyles.caption,
                ),
              ),
              IconButton(
                  tooltip: 'Sửa định lượng',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeRecipeQuantity(line),
                  icon: const Icon(Icons.edit_outlined, size: 18)),
              IconButton(
                  tooltip: 'Bỏ nguyên liệu khỏi công thức',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmRemoveRecipeLine(line),
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 18)),
            ]),
          TextButton.icon(
            onPressed: () => _addRecipeLine(size),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm nguyên liệu'),
          ),
        ],
      ]),
    );
  }
}

class _MenuItemInput {
  const _MenuItemInput(
      {required this.name,
      required this.group,
      required this.size,
      required this.price});
  final String name;
  final String group;
  final String size;
  final int price;
}

class _MenuMessage extends StatelessWidget {
  const _MenuMessage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.bodyStrong),
          const SizedBox(height: 3),
          Text(body, style: AppTextStyles.caption),
        ]),
      );
}

String _friendlyError(Object error) {
  if (error is PostgrestException) {
    if (error.message.contains('RECIPE_IN_USE')) {
      return 'Size đã được dùng trong bill. Hãy ẩn size cũ rồi tạo size mới để giữ đúng lịch sử đối soát.';
    }
    return switch (error.code) {
      '23505' => 'Tên món hoặc size này đã tồn tại.',
      '23503' => 'Không thể đổi công thức vì size đã được dùng trong bill.',
      '42501' => 'Chỉ chủ quán mới được sửa thực đơn.',
      _ => 'Không lưu được thay đổi. Hãy kiểm tra dữ liệu và thử lại.',
    };
  }
  return 'Có lỗi kết nối. Hãy thử lại.';
}
