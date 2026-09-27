// lib/widgets/common/navigation/navigation_item.dart
library;

import 'package:flutter/widgets.dart';

/// One navigation destination. Its identity is [route], never its position.
class AdaptiveNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final int? badgeCount;

  /// Semantic label for screen readers. Defaults to label if not provided.
  final String? semanticLabel;

  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badgeCount,
    this.semanticLabel,
  });

  /// Get the semantic label, falling back to label if not set.
  String get accessibleLabel => semanticLabel ?? label;
}
