// lib/widgets/styled/styled_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/animated_pressable.dart';

/// Pre-styled button widgets to eliminate design-in-views violations
/// Provides consistent button styling patterns used throughout the app
class StyledButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDestructive;
  final Widget? icon;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  /// Semantic label for screen readers.
  /// Defaults to [text] if not provided. Important for icon-only buttons.
  final String? semanticLabel;

  /// Whether to show press animation feedback.
  /// Respects user's "Reduce Motion" accessibility setting.
  final bool enablePressAnimation;

  /// Tooltip for icon buttons — shown on long-press and used by screen readers.
  final String? tooltip;

  const StyledButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.semanticLabel,
    this.enablePressAnimation = true,
    this.tooltip,
  });

  /// Primary elevated button
  const StyledButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.semanticLabel,
    this.enablePressAnimation = true,
  })  : isDestructive = false,
        height = AppDimensions.buttonHeight,
        padding = null,
        tooltip = null;

  /// Secondary outlined button
  const StyledButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.semanticLabel,
    this.enablePressAnimation = true,
  })  : isDestructive = false,
        height = AppDimensions.buttonHeight,
        padding = null,
        tooltip = null;

  /// Destructive button (delete, remove actions)
  const StyledButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.semanticLabel,
    this.enablePressAnimation = true,
  })  : isDestructive = true,
        height = AppDimensions.buttonHeight,
        padding = null,
        tooltip = null;

  /// Small button for compact spaces
  const StyledButton.small({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
    this.enablePressAnimation = true,
  })  : isDestructive = false,
        width = null,
        height = 36.0,
        padding = null,
        tooltip = null;

  /// Icon-only button. [semanticLabel] is required for accessibility.
  const StyledButton.icon({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
    this.enablePressAnimation = true,
    this.tooltip,
  })  : text = '',
        width = null,
        height = AppDimensions.buttonHeight,
        padding = null;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = semanticLabel ?? text;

    if (isLoading) {
      return Semantics(
        label: '$effectiveLabel, ${context.l10n.commonLoading}',
        button: true,
        enabled: false,
        child: SizedBox(
          width: width,
          height: height ?? AppDimensions.buttonHeight,
          child: ElevatedButton(
            onPressed: null,
            style: _getButtonStyle(context),
            child: const SizedBox(
              width: (AppDimensions.spacingMd + AppDimensions.spacingXs),
              height: (AppDimensions.spacingMd + AppDimensions.spacingXs),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (text.isEmpty && icon != null) {
      final iconButton = Semantics(
        label: effectiveLabel,
        button: true,
        enabled: onPressed != null,
        child: SizedBox(
          width: width ?? AppDimensions.buttonHeight,
          height: height ?? AppDimensions.buttonHeight,
          child: isDestructive
              ? _buildDestructiveIconButton(context)
              : _buildIconButton(context),
        ),
      );
      return _wrapWithAnimation(iconButton);
    }

    final button = SizedBox(
      width: width,
      height: height ?? AppDimensions.buttonHeight,
      child: isDestructive
          ? _buildDestructiveButton(context)
          : _buildRegularButton(context),
    );
    return _wrapWithAnimation(button);
  }

  /// Wraps the button with AnimatedPressable for press feedback.
  Widget _wrapWithAnimation(Widget button) {
    if (!enablePressAnimation) return button;
    return AnimatedPressable(
      enabled: onPressed != null,
      child: button,
    );
  }

  Widget _buildRegularButton(BuildContext context) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: _getButtonStyle(context),
        icon: icon!,
        label: Text(text),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: _getButtonStyle(context),
      child: Text(text),
    );
  }

  Widget _buildDestructiveButton(BuildContext context) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: _getDestructiveButtonStyle(context),
        icon: icon!,
        label: Text(text),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: _getDestructiveButtonStyle(context),
      child: Text(text),
    );
  }

  Widget _buildIconButton(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
      ),
      icon: icon!,
    );
  }

  Widget _buildDestructiveIconButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        ),
      ),
      icon: icon!,
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    EdgeInsetsGeometry effectivePadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        );

    if (height != null && height! < AppDimensions.buttonHeight) {
      effectivePadding = const EdgeInsets.symmetric(
        horizontal: (AppDimensions.spacingSm + AppDimensions.spacingXs),
        vertical: AppDimensions.spacingSm,
      );
    }

    return ElevatedButton.styleFrom(
      padding: effectivePadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      ),
      textStyle: AppTextStyles.buttonText,
      elevation: AppDimensions.elevationLow,
    );
  }

  ButtonStyle _getDestructiveButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      backgroundColor: cs.errorContainer,
      foregroundColor: cs.onErrorContainer,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      ),
      textStyle: AppTextStyles.buttonText,
      elevation: AppDimensions.elevationLow,
    );
  }
}

/// Specialized button variants for common patterns
class StyledButtons {
  /// Cancel button (typically used in dialogs)
  static Widget cancel({
    VoidCallback? onPressed,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.secondary(
        text: text ?? context.l10n.commonCancel,
        onPressed: onPressed,
      ),
    );
  }

  /// Save button
  static Widget save({
    VoidCallback? onPressed,
    bool isLoading = false,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.primary(
        text: text ?? context.l10n.commonSave,
        onPressed: onPressed,
        isLoading: isLoading,
        icon: const Icon(Icons.save),
      ),
    );
  }

  /// Delete button
  static Widget delete({
    VoidCallback? onPressed,
    bool isLoading = false,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.destructive(
        text: text ?? context.l10n.commonDelete,
        onPressed: onPressed,
        isLoading: isLoading,
        icon: const Icon(Icons.delete),
      ),
    );
  }

  /// Add button
  static Widget add({
    VoidCallback? onPressed,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.primary(
        text: text ?? context.l10n.commonAdd,
        onPressed: onPressed,
        icon: const Icon(Icons.add),
      ),
    );
  }

  /// Edit button
  static Widget edit({
    VoidCallback? onPressed,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.secondary(
        text: text ?? context.l10n.commonEdit,
        onPressed: onPressed,
        icon: const Icon(Icons.edit),
      ),
    );
  }

  /// Share button
  static Widget share({
    VoidCallback? onPressed,
    String? text,
  }) {
    return Builder(
      builder: (context) => StyledButton.secondary(
        text: text ?? context.l10n.commonShare,
        onPressed: onPressed,
        icon: const Icon(Icons.share),
      ),
    );
  }
}
