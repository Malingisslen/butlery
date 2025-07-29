// lib/widgets/messaging/error_text.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Styled error text with consistent error color
class ErrorText extends StatelessWidget {
  final String text;

  const ErrorText(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.error),
    );
  }
}