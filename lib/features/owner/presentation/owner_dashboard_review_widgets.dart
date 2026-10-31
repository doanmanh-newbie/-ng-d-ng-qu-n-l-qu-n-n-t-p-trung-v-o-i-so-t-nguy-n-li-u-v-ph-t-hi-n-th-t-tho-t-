part of 'owner_home_screen.dart';

class _CashResultCard extends StatelessWidget {
  const _CashResultCard({
    required this.cash,
    required this.variance,
    required this.severity,
  });
  final Map<String, dynamic> cash;
  final int variance;
  final StatusSeverity severity;

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
            Row(children: [
              const Expanded(
                child: Text('Tiền mặt cuối ca',
                    style: TextStyle(color: Colors.white70)),
              ),
              StatusChip(
                label: _cashVarianceStatus(variance),
                severity: severity,
                compact: true,
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              formatVnd(variance.abs()),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s24,
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
          Row(children: [
            const Expanded(
              child: Text('Trạng thái xử lý', style: AppTextStyles.title),
            ),
            StatusChip(
              label: _handled ? 'Đã xử lý' : 'Chưa xử lý',
              severity:
                  _handled ? StatusSeverity.healthy : StatusSeverity.attention,
              compact: true,
            ),
          ]),
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
