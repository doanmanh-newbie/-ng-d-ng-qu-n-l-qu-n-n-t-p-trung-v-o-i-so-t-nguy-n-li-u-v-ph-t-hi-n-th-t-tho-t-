import 'package:flutter/material.dart';

import 'status_pill.dart';
import '../widgets/status_chip.dart';

class SeverityChip extends StatelessWidget {
  const SeverityChip({
    super.key,
    required this.label,
    required this.severity,
  });

  final String label;
  final StatusSeverity severity;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: label,
        severity: severity,
        compact: true,
      );
}
