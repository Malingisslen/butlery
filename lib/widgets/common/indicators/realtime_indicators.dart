// lib/widgets/common/indicators/realtime_indicators.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';

/// Realtime indicators facade for collaborative features
/// This facade provides a unified interface to realtime indicator widgets:
/// - RealtimeStatusWidget: Shows connection status
/// - RealtimeStatusBanner: Shows offline banner
/// **SRP Compliance:** This file follows the facade pattern - it delegates
/// to specialized widget modules rather than implementing widgets directly.
class RealtimeIndicators {
  /// 🌐 Connection status indikator
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return RealtimeStatusWidget(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding,
    );
  }

  /// Expanded status banner for larger displays
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return RealtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }
}
