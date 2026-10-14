import 'package:flutter/material.dart';

/// Accessibility utilities for text scaling and layout protection.
class AccessibilityUtils {
  AccessibilityUtils._();

  /// The app-wide text-scale ceiling set at the MaterialApp root; raise it
  /// only after the fixed-height surfaces are gone (T9).
  static const double maxTextScale = 1.4;

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
