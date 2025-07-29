// lib/widgets/messaging/error_list_tile.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/messaging/error_text.dart';

/// Styled ListTile for error actions with consistent error theming
class ErrorListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ErrorListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.error),
      title: ErrorText(title),
      onTap: onTap,
    );
  }
}