// lib/widgets/common/indicators/connection_dot.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';

/// A small round dot in the design's status colours, so connection state
/// never needs an emoji.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({required this.status, super.key});

  final ConnectionStatus status;

  static const double size = AppDimensions.space8;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorFor(context, status),
        shape: BoxShape.circle,
      ),
    );
  }

  static Color colorFor(BuildContext context, ConnectionStatus status) {
    final modeColors = context.modeColors;
    switch (status) {
      case ConnectionStatus.connected:
        return modeColors.success;
      case ConnectionStatus.disconnected:
        return Theme.of(context).colorScheme.error;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return modeColors.warning;
      case ConnectionStatus.unknown:
        return modeColors.neutral;
    }
  }
}
