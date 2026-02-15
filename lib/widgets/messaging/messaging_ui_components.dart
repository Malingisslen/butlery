import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Consolidated messaging UI components.

/// Styled error text with consistent error color.
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
      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      leading: Icon(icon, color: Theme.of(context).colorScheme.error),
      title: ErrorText(title),
      onTap: onTap,
    );
  }
}

/// Styled header text for modal content.
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
          style: AppTextStyles.sectionHeader,
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

/// Styled container for search bar in conversations view.
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
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}
