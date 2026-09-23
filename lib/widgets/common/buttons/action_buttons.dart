// lib/widgets/common/buttons/action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// ActionButtons - Utility action buttons with a busy state.
///
/// A busy button (`isLoading`) keeps its shape, its colours and its name, or
/// says what it is doing (`loadingText`, the busy label, e.g. "Sparar …"),
/// and gets the plate line along its bottom edge in its own text colour
/// (Komponentark v1:307, :365, :372; Grafisk manual v6:423; B-18). It never
/// shows a spinner and never falls back to "Laddar...".
class ActionButtons {
  /// The visible label: the busy label while busy, else the button's name.
  static String _visibleLabel(bool busy, String name, String? busyLabel) =>
      busy ? (busyLabel ?? name) : name;

  static Widget actionButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
    bool enablePressAnimation = true,
  }) {
    final effectiveOnPressed = isLoading ? PlateLineButton.ignore : onPressed;
    final effectiveLabel = _visibleLabel(isLoading, label, loadingText);

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A busy button shows its words only, as drawn (Komponentark
          // v1:372).
          if (icon != null && !isLoading)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingS,
              ),
              child: Icon(icon),
            ),
          Flexible(
            child: Text(
              effectiveLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    final theme = Theme.of(context);
    Widget button;
    switch (style) {
      case ActionButtonStyle.primary:
      case ActionButtonStyle.secondary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: isLoading
              ? PlateLineButton.busyStyle(
                  null,
                  theme.elevatedButtonTheme.style,
                )
              : null,
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: isLoading
              ? PlateLineButton.busyStyle(
                  null,
                  theme.outlinedButtonTheme.style,
                )
              : null,
          child: buttonChild,
        );
        break;
    }

    final sized = isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: button,
          );

    if (isLoading) {
      return BusyButtonSemantics(
        busy: true,
        name: label,
        busyLabel: loadingText,
        child: sized,
      );
    }

    final result = Semantics(
      label: label,
      button: true,
      enabled: effectiveOnPressed != null,
      child: sized,
    );

    if (!enablePressAnimation) return result;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: result,
    );
  }

  /// Primary action button convenience method
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    bool enablePressAnimation = true,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.primary,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
    );
  }

  /// Square button for recipe upload view - perfect square aspect ratio
  static Widget squareButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
    bool enablePressAnimation = true,
  }) {
    final square = AspectRatio(
      aspectRatio: 1.0, // Perfect square
      child: ElevatedButton(
        onPressed: isLoading ? PlateLineButton.ignore : onPressed,
        style: isLoading
            ? PlateLineButton.busyStyle(
                null,
                Theme.of(context).elevatedButtonTheme.style,
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLoading) ...[
              Icon(icon, size: AppDimensions.iconSizeXl),
              const SizedBox(height: AppDimensions.spacingSm),
            ],
            // Flexible, not a bare Text: the canonical type scale carries an
            // explicit line height, so two lines are taller than they were
            // under the old metrics and a fixed 1:1 square overflowed by 4px.
            // The label still ellipsises at two lines; only the free growth
            // is capped.
            Flexible(
              child: Text(
                _visibleLabel(isLoading, label, loadingText),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (isLoading) {
      return BusyButtonSemantics(
        busy: true,
        name: label,
        busyLabel: loadingText,
        child: square,
      );
    }

    final result = Semantics(
      label: label,
      button: true,
      enabled: true,
      child: square,
    );

    if (!enablePressAnimation) return result;
    return AnimatedPressable(
      enabled: true,
      child: result,
    );
  }

  /// Large prominent button for important actions (like archive)
  static Widget largeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
    double height = 100, // Slightly increased height
    EdgeInsets? margin,
    bool enablePressAnimation = true,
  }) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final sized = SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? PlateLineButton.ignore : onPressed,
        style: isLoading
            ? PlateLineButton.busyStyle(
                null,
                Theme.of(context).elevatedButtonTheme.style,
              )
            : null,
        icon: isLoading
            ? null
            : Icon(icon, size: AppDimensions.iconSizeXl, color: onPrimary),
        label: Text(
          _visibleLabel(isLoading, label, loadingText),
          style: AppTextStyles.labelLarge.copyWith(color: onPrimary),
        ),
      ),
    );

    final Widget button = isLoading
        ? BusyButtonSemantics(
            busy: true,
            name: label,
            busyLabel: loadingText,
            child: sized,
          )
        : Semantics(
            label: label,
            button: true,
            enabled: true,
            child: sized,
          );

    final Widget result = margin != null
        ? Padding(padding: margin, child: button)
        : button;

    if (!enablePressAnimation || isLoading) return result;
    return AnimatedPressable(
      enabled: true,
      child: result,
    );
  }

  /// Secondary action button convenience method
  static Widget secondaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    bool enablePressAnimation = true,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.secondary,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
    );
  }

  /// Outlined action button convenience method
  static Widget outlinedButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    bool enablePressAnimation = true,
  }) {
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.outlined,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
    );
  }

  /// Text button convenience method for minimal styling
  static Widget textButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    ButtonStyle? style,
    bool enablePressAnimation = true,
  }) {
    final effectiveOnPressed = isLoading ? PlateLineButton.ignore : onPressed;
    final effectiveLabel = _visibleLabel(isLoading, label, loadingText);

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A busy button shows its words only, as drawn (Komponentark
          // v1:372).
          if (icon != null && !isLoading)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingS,
              ),
              child: Icon(icon),
            ),
          Flexible(
            child: Text(
              effectiveLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    final button = TextButton(
      onPressed: effectiveOnPressed,
      style: isLoading
          ? PlateLineButton.busyStyle(
              style,
              Theme.of(context).textButtonTheme.style,
            )
          : style,
      child: buttonChild,
    );

    final sized = isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;

    if (isLoading) {
      return BusyButtonSemantics(
        busy: true,
        name: label,
        busyLabel: loadingText,
        child: sized,
      );
    }

    final result = Semantics(
      label: label,
      button: true,
      enabled: effectiveOnPressed != null,
      child: sized,
    );

    if (!enablePressAnimation) return result;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: result,
    );
  }

  /// Cancel button that pops the current context.
  static Widget cancel<T>(
    BuildContext context, {
    String? label,
    T? result,
  }) {
    return secondaryButton(
      context,
      label: label ?? context.l10n.commonCancel,
      onPressed: () => Navigator.pop(context, result ?? false),
    );
  }
}

/// Floating Action Button Widget
/// Provides consistent FAB styling across the app following design separation principles.
class FloatingActionButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Semantic label for screen readers. Required for accessibility.
  final String semanticLabel;

  /// Whether to show press animation feedback.
  final bool enablePressAnimation;

  const FloatingActionButtonWidget({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.enablePressAnimation = true,
  });

  /// Message FAB for conversations. `semanticLabel` is required so the caller
  /// supplies a localized string (e.g. `context.l10n.messagingNewConversation`)
  /// — a const default here would lock the screen-reader label to one language.
  const FloatingActionButtonWidget.message({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.enablePressAnimation = true,
  }) : child = const Icon(Icons.message),
       backgroundColor = null,
       foregroundColor = null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        backgroundColor: backgroundColor ?? cs.primary,
        foregroundColor: foregroundColor ?? cs.surfaceContainerHighest,
        child: child,
      ),
    );

    if (!enablePressAnimation) return result;
    return AnimatedPressable(
      enabled: onPressed != null,
      child: result,
    );
  }
}

/// Button style enumeration
enum ActionButtonStyle { primary, secondary, outlined }

/// Canonical icon-only button for the Butlery design system.
///
/// Enforces WCAG 4.1.2 by requiring [semanticLabel]. Wraps [IconButton] so
/// Material's 48dp minimum touch target (WCAG 2.5.5) is preserved.
/// Use this in place of raw [IconButton] for any icon-only action.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color,
    this.iconSize,
    this.padding,
    super.key,
  });

  /// The icon to render.
  final IconData icon;

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Required screen-reader label (also used as tooltip).
  /// Must be provided from `AppLocalizations` — no hardcoded Swedish.
  final String semanticLabel;

  /// Icon tint. Defaults to the theme's icon theme color.
  final Color? color;

  /// Icon glyph size. Defaults to [IconButton]'s Material default (24).
  final double? iconSize;

  /// Padding inside the button; affects visual size but not the 48dp hit area.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Explicit Semantics mirrors the idiom used by the other buttons in this
    // file — tooltip alone doesn't always surface on the semantic tree when
    // the IconButton is nested under interactive ancestors.
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      child: IconButton(
        icon: Icon(icon, color: color, size: iconSize),
        onPressed: onPressed,
        tooltip: semanticLabel,
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingSm),
      ),
    );
  }
}
