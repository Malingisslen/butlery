// lib/widgets/messaging/messaging_ui_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Consolidated messaging UI components
/// This file contains simple utility widgets for messaging UI:
/// - ErrorText: Styled error text with consistent error color
/// - ErrorListTile: ListTile for error actions with error theming
/// - ModalHeaderText: Header text for modal content
/// - ModalContentContainer: Container wrapper for modal content
/// - SearchBarContainer: Container for search bar in conversations view
/// - StyledModalBottomSheet: Helper for showing modal bottom sheets
/// **Consolidation**: Merged from 6 separate files (146 LOC) for better maintainability

// ===== ERROR COMPONENTS =====

/// Styled error text with consistent error color
class ErrorText extends StatelessWidget {
  final String text;

  const ErrorText(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.error),
    );
  }
}

/// Styled ListTile for error actions with consistent error theming
class ErrorListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ErrorListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.error),
      title: ErrorText(title),
      onTap: onTap,
    );
  }
}

// ===== MODAL COMPONENTS =====

/// Styled header text for modal content
class ModalHeaderText extends StatelessWidget {
  final String text;

  const ModalHeaderText(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          text,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingL),
      ],
    );
  }
}

/// Styled container for modal content
class ModalContentContainer extends StatelessWidget {
  final List<Widget> children;

  const ModalContentContainer({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Styled modal bottom sheet for messaging dialogs
class StyledModalBottomSheet {
  /// Show a styled modal bottom sheet with consistent theming
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) => child,
    );
  }
}

// ===== CONTAINER COMPONENTS =====

/// Styled container for search bar in conversations view
class SearchBarContainer extends StatelessWidget {
  final Widget child;

  const SearchBarContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      color: AppColors.backgroundBeige,
      child: child,
    );
  }
}
