import 'package:flutter/material.dart';

/// Accessibility utilities for text scaling and layout protection.
class AccessibilityUtils {
  AccessibilityUtils._();

  /// Wraps [child] with a clamped text scaler to prevent small text
  /// from overflowing fixed-height containers at high scale factors.
  static Widget clampTextScaling({
    required BuildContext context,
    required Widget child,
    double maxScaleFactor = 1.3,
  }) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(maxScaleFactor: maxScaleFactor),
      ),
      child: child,
    );
  }
}
