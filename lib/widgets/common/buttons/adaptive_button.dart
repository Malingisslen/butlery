/// Platform-adaptive button widget.
/// Uses CupertinoButton on iOS for navigation contexts,
/// Material buttons on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// A platform-adaptive button for navigation and action contexts.
/// Uses CupertinoButton on iOS and TextButton/ElevatedButton on Android.
///
/// Note: For content-area buttons (cards, forms), Material buttons are
/// acceptable on both platforms per iOS HIG guidelines. Use this widget
/// specifically for navigation bars, toolbars, and modal actions.
class AdaptiveButton extends StatelessWidget {
  /// Creates a platform-adaptive button.
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.disabledColor,
    this.padding,
    this.minSize = 44.0,
  });

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// The button's content.
  final Widget child;

  /// The button's color. Uses theme primary color if not specified.
  final Color? color;

  /// The button's color when disabled.
  final Color? disabledColor;

  /// Padding around the button content.
  final EdgeInsetsGeometry? padding;

  /// Minimum size for touch targets.
  final double minSize;

  /// Creates a primary action button (filled style).
  const AdaptiveButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding,
    this.minSize = 44.0,
  }) : color = null,
       disabledColor = null;

  /// Creates a text-style button for secondary actions.
  factory AdaptiveButton.text({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    Color? color,
    EdgeInsetsGeometry? padding,
  }) {
    return _AdaptiveTextButton(
      key: key,
      onPressed: onPressed,
      color: color,
      padding: padding,
      child: child,
    );
  }

  /// Creates a destructive action button (red styling).
  factory AdaptiveButton.destructive({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return _AdaptiveDestructiveButton(
      key: key,
      onPressed: onPressed,
      padding: padding,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: padding,
        minimumSize: Size(minSize, minSize),
        disabledColor: disabledColor ?? CupertinoColors.quaternarySystemFill,
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding,
        minimumSize: Size(minSize, minSize),
        foregroundColor: color,
        disabledForegroundColor: disabledColor,
      ),
      child: child,
    );
  }
}

/// Internal text button variant.
class _AdaptiveTextButton extends AdaptiveButton {
  const _AdaptiveTextButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.color,
    super.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: padding ?? EdgeInsets.zero,
        minimumSize: Size(minSize, minSize),
        child: DefaultTextStyle(
          style: AppTextStyles.labelLarge.copyWith(
            color: color ?? CupertinoColors.activeBlue.resolveFrom(context),
          ),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: padding,
        foregroundColor: color,
      ),
      child: child,
    );
  }
}

/// Internal destructive button variant.
class _AdaptiveDestructiveButton extends AdaptiveButton {
  const _AdaptiveDestructiveButton({
    super.key,
    required super.onPressed,
    required super.child,
    super.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: padding ?? EdgeInsets.zero,
        minimumSize: Size(minSize, minSize),
        child: DefaultTextStyle(
          style: AppTextStyles.labelLarge.copyWith(
            color: CupertinoColors.destructiveRed,
          ),
          child: child,
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: padding,
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      child: child,
    );
  }
}

/// A platform-adaptive icon button.
/// Uses CupertinoButton on iOS, IconButton on Android.
///
/// [semanticLabel] is required for accessibility (WCAG 4.1.2).
/// It is used as both the visible tooltip (Android) and the
/// screen-reader announcement on every platform.
class AdaptiveIconButton extends StatelessWidget {
  /// Creates a platform-adaptive icon button.
  const AdaptiveIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color,
    this.size = 24.0,
    this.padding,
  });

  /// The icon to display.
  final Widget icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// The icon's color.
  final Color? color;

  /// Required accessibility label — announced by screen readers and shown
  /// as the tooltip on long-press (Material) or on hover (web/desktop).
  final String semanticLabel;

  /// The icon's size.
  final double size;

  /// Padding around the icon.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
      return Tooltip(
        message: semanticLabel,
        child: Semantics(
          label: semanticLabel,
          button: true,
          enabled: onPressed != null,
          child: CupertinoButton(
            onPressed: onPressed,
            padding: padding ?? const EdgeInsets.all(AppDimensions.spacingSm),
            minimumSize: const Size(
              AppDimensions.minTouchTarget,
              AppDimensions.minTouchTarget,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: color ?? CupertinoColors.activeBlue.resolveFrom(context),
                size: size,
              ),
              child: icon,
            ),
          ),
        ),
      );
    }

    return IconButton(
      icon: icon,
      onPressed: onPressed,
      color: color,
      tooltip: semanticLabel,
      iconSize: size,
      padding: padding,
    );
  }
}
