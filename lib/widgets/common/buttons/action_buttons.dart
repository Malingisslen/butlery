// lib/widgets/common/buttons/action_buttons.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';
import 'package:butlery/widgets/common/buttons/square_button_style.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

export 'package:butlery/widgets/common/buttons/app_icon_button.dart';

/// ActionButtons - Utility action buttons with a busy state.
///
/// A busy button (`isLoading`) keeps its shape, its colours and its name, or
/// says what it is doing (`loadingText`, the busy label, e.g. "Sparar …"),
/// and gets the plate line along its bottom edge in its own text colour
/// (B-18). It never
/// shows a spinner and never falls back to "Laddar...".
class ActionButtons {
  /// The widest a button that does not fill its row grows, at normal text.
  static const double _maxButtonWidth = 200;

  static const ButtonStyle _hugLabel = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(0, AppDimensions.controlVisualHeight),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  /// The visible label: the busy label while busy, else the button's name.
  static String _visibleLabel(bool busy, String name, String? busyLabel) =>
      busy ? (busyLabel ?? name) : name;

  /// A label that wraps between words. At large text a word wider than the
  /// button is scaled down until it fits, since breaking it between letters
  /// reads as a typing error; the button's own text style is the one measured.
  /// Only a button that fills its row is measured: one that hugs its label is
  /// also asked for intrinsic sizes (a dialog's action row does), which the
  /// measuring widget cannot give.
  static Widget _label(
    BuildContext context,
    String text,
    bool isLoading,
    String? semanticLabel,
    bool isExpanded,
  ) {
    final semantics = isLoading ? null : semanticLabel;
    if (!isExpanded || !isLargeText(context)) {
      return Text(
        text,
        semanticsLabel: semantics,
        textAlign: TextAlign.center,
      );
    }
    return WholeWordText(
      text,
      style: const TextStyle(),
      semanticsLabel: semantics,
      textAlign: TextAlign.center,
    );
  }

  static Widget actionButton(
    BuildContext context, {
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
    bool enablePressAnimation = true,
    String? semanticLabel,
    bool square = false,
  }) {
    final effectiveOnPressed = isLoading ? PlateLineButton.ignore : onPressed;
    final effectiveLabel = _visibleLabel(isLoading, label, loadingText);

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A busy button shows its words only, as drawn (Komponentark
          // v1:372).
          if (icon != null && !isLoading)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space4,
              ),
              child: ButleryIcon(icon),
            ),
          Flexible(
            // BUT-2193: a label wraps rather than ellipsising; a button
            // never cuts its own name (systemtextstorlek).
            child: _label(
              context,
              effectiveLabel,
              isLoading,
              semanticLabel,
              isExpanded,
            ),
          ),
        ],
      ),
    );

    final theme = Theme.of(context);
    final filled =
        style != ActionButtonStyle.outlined &&
        style != ActionButtonStyle.outlinedOnInk &&
        style != ActionButtonStyle.danger;
    // The secondary button rests on the raised surface behind an outline, so
    // its busy line takes the text colour, not the filled button's.
    final onFill = filled && style != ActionButtonStyle.secondary;
    final ButtonStyle? styled = switch (style) {
      ActionButtonStyle.primary => null,
      ActionButtonStyle.secondary => ComponentThemes.secondaryButtonStyle(
        theme.colorScheme,
      ),
      ActionButtonStyle.outlined => null,
      ActionButtonStyle.onInk => ComponentThemes.onInkButtonStyle(
        theme.colorScheme,
      ),
      ActionButtonStyle.outlinedOnInk =>
        ComponentThemes.outlinedOnInkButtonStyle(theme.colorScheme),
      ActionButtonStyle.danger => ComponentThemes.deleteButtonStyle(
        theme.colorScheme,
      ),
    };
    final ButtonStyle? variant = square
        ? (styled ?? const ButtonStyle()).merge(
            squareButtonStyle(theme, filled: filled),
          )
        : styled;
    // The theme's minimum width is infinite so a button fills a column; a
    // button that is not expanded hugs its label instead, up to the cap below.
    final own = isExpanded ? variant : _hugLabel.merge(variant);
    final ButtonStyle? effectiveStyle = isLoading
        ? PlateLineButton.busyStyle(
            own,
            filled
                ? theme.elevatedButtonTheme.style
                : theme.outlinedButtonTheme.style,
            onFill: onFill,
          )
        : own;
    final Widget button = filled
        ? ElevatedButton(
            key: key,
            onPressed: effectiveOnPressed,
            style: effectiveStyle,
            child: buttonChild,
          )
        : OutlinedButton(
            key: key,
            onPressed: effectiveOnPressed,
            style: effectiveStyle,
            child: buttonChild,
          );

    final sized = isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : ConstrainedBox(
            // The cap grows with the text, or a scaled label would wrap
            // inside it and break its words.
            constraints: BoxConstraints(
              maxWidth: MediaQuery.textScalerOf(context).scale(_maxButtonWidth),
            ),
            child: button,
          );

    if (isLoading) {
      return BusyButtonSemantics(
        busy: true,
        name: semanticLabel ?? label,
        busyLabel: loadingText,
        child: sized,
      );
    }

    // The Material button is the one button node and carries the name
    // (`semanticsLabel` on its text); a Semantics wrapper here would read it
    // twice (BUT-2253, ui-conventions rule 6).
    if (!enablePressAnimation) return sized;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: sized,
    );
  }

  /// Primary action button convenience method
  static Widget primaryButton(
    BuildContext context, {
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    bool enablePressAnimation = true,
    bool square = false,
  }) {
    return actionButton(
      context,
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.primary,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
      square: square,
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
    final onPrimary = AppModeColors.onActionFill(Theme.of(context).brightness);
    final sized = ConstrainedBox(
      // A floor: the button grows with large text instead of clipping it.
      constraints: BoxConstraints(minHeight: height),
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
            : ButleryIcon(
                icon,
                size: AppDimensions.iconSizeXl,
                color: onPrimary,
              ),
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
        : sized;

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
    Key? key,
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
      key: key,
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
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    bool enablePressAnimation = true,
    String? semanticLabel,
    bool square = false,
  }) {
    return actionButton(
      context,
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.outlined,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
      square: square,
      semanticLabel: semanticLabel,
    );
  }

  /// The red outlined button of a destructive action that sits in a page
  /// rather than a dialog (Radera konto, Radera innehåll).
  static Widget dangerButton(
    BuildContext context, {
    Key? key,
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
      key: key,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.danger,
      isExpanded: isExpanded,
      enablePressAnimation: enablePressAnimation,
    );
  }

  /// Text button convenience method for minimal styling
  static Widget textButton(
    BuildContext context, {
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
    ButtonStyle? style,
    bool enablePressAnimation = true,
    bool iconAtEnd = false,
  }) {
    final effectiveOnPressed = isLoading ? PlateLineButton.ignore : onPressed;
    final effectiveLabel = _visibleLabel(isLoading, label, loadingText);

    final Widget buttonChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A busy button shows its words only, as drawn (Komponentark
          // v1:372).
          if (icon != null && !isLoading && !iconAtEnd)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space4,
              ),
              child: ButleryIcon(icon),
            ),
          Flexible(
            // BUT-2193: a label wraps rather than ellipsising; a button
            // never cuts its own name (systemtextstorlek).
            child: Text(
              effectiveLabel,
              textAlign: TextAlign.center,
            ),
          ),
          if (icon != null && !isLoading && iconAtEnd)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.space4,
              ),
              child: ButleryIcon(icon),
            ),
        ],
      ),
    );

    final button = TextButton(
      key: key,
      onPressed: effectiveOnPressed,
      style: isLoading
          ? PlateLineButton.busyStyle(
              style,
              Theme.of(context).textButtonTheme.style,
              onFill: false,
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

    if (!enablePressAnimation) return sized;
    return AnimatedPressable(
      enabled: effectiveOnPressed != null,
      child: sized,
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
  }) : child = const ButleryIcon(ButleryIcons.messageSquare),
       backgroundColor = null,
       foregroundColor = null;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // FloatingActionButton puts its tooltip on a node above its button node,
    // leaving the button unnamed; the name goes inside the button instead.
    final result = Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: PressFill(
        surface: PressSurface.ink,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor:
              backgroundColor ?? AppModeColors.actionFill(brightness),
          foregroundColor:
              foregroundColor ?? AppModeColors.onActionFill(brightness),
          child: Semantics(label: semanticLabel, child: child),
        ),
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
/// [onInk] and [outlinedOnInk] are for a button that sits on surface.ink
/// (the Hem hero band, an ink overlay), where the ink primary would vanish.
///
/// [danger] is the red outlined button of a destructive action.
enum ActionButtonStyle {
  primary,
  secondary,
  outlined,
  onInk,
  outlinedOnInk,
  danger,
}
