import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Indikator som visar om en användare är online eller offline
class UserPresenceIndicator extends StatelessWidget {
  final bool isOnline;

  const UserPresenceIndicator({
    super.key,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppTheme.successColor : AppTheme.errorColor;

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
