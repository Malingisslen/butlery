// lib/widgets/styled/styled_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
  });

  /// Primary elevated button
  const StyledButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  })  : isDestructive = false,
        height = AppDimensions.buttonHeight,
        padding = null;

  /// Secondary outlined button
  const StyledButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  })  : isDestructive = false,
        height = AppDimensions.buttonHeight,
        padding = null;

  /// Destructive button (delete, remove actions)
  const StyledButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  })  : isDestructive = true,
        height = AppDimensions.buttonHeight,
        padding = null;

  /// Small button for compact spaces
  const StyledButton.small({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  })  : isDestructive = false,
        width = null,
        height = 36.0,
        padding = null;

  /// Icon-only button
  const StyledButton.icon({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
  })  : text = '',
        width = null,
        height = AppDimensions.buttonHeight,
        padding = null;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
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
      );
    }

    if (text.isEmpty && icon != null) {
      return SizedBox(
        width: width ?? AppDimensions.buttonHeight,
        height: height ?? AppDimensions.buttonHeight,
        child: isDestructive
            ? _buildDestructiveIconButton(context)
            : _buildIconButton(context),
      );
    }

    return SizedBox(
      width: width,
      height: height ?? AppDimensions.buttonHeight,
      child: isDestructive
          ? _buildDestructiveButton(context)
          : _buildRegularButton(context),
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
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.errorContainer,
        foregroundColor: AppColors.onErrorContainer,
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
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.errorContainer,
      foregroundColor: AppColors.onErrorContainer,
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
    String text = 'Avbryt',
  }) {
    return StyledButton.secondary(
      text: text,
      onPressed: onPressed,
    );
  }

  /// Save button
  static Widget save({
    VoidCallback? onPressed,
    bool isLoading = false,
    String text = 'Spara',
  }) {
    return StyledButton.primary(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: const Icon(Icons.save),
    );
  }

  /// Delete button
  static Widget delete({
    VoidCallback? onPressed,
    bool isLoading = false,
    String text = 'Ta bort',
  }) {
    return StyledButton.destructive(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: const Icon(Icons.delete),
    );
  }

  /// Add button
  static Widget add({
    VoidCallback? onPressed,
    String text = 'Lägg till',
  }) {
    return StyledButton.primary(
      text: text,
      onPressed: onPressed,
      icon: const Icon(Icons.add),
    );
  }

  /// Edit button
  static Widget edit({
    VoidCallback? onPressed,
    String text = 'Redigera',
  }) {
    return StyledButton.secondary(
      text: text,
      onPressed: onPressed,
      icon: const Icon(Icons.edit),
    );
  }

  /// Share button
  static Widget share({
    VoidCallback? onPressed,
    String text = 'Dela',
  }) {
    return StyledButton.secondary(
      text: text,
      onPressed: onPressed,
      icon: const Icon(Icons.share),
    );
  }
}
