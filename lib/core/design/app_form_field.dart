import 'package:flutter/material.dart';

import '../widgets/app_text_field.dart';

/// Trường nhập thống nhất có nhãn, gợi ý và lỗi đặt ngay dưới ô.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AppTextField(
        label: label,
        controller: controller,
        hint: hint,
        errorText: errorText,
        keyboardType: keyboardType,
        enabled: enabled,
      );
}
