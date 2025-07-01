import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Enkel dela-knapp för realtidsfunktioner
class ShareButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const ShareButtonWidget({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AppTheme.actionIcon(context, Icons.share),
      onPressed: onPressed,
      tooltip: 'Dela',
    );
  }
}
