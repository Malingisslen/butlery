import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Liten indikator som visar om realtidsaktivitet pågår
class LiveActivityIndicator extends StatelessWidget {
  final bool isActive;

  const LiveActivityIndicator({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.successColor : AppTheme.textSecondary;

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
