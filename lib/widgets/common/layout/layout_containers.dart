// lib/widgets/common/layout/layout_containers.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Consolidated layout container widgets
/// This file contains simple utility widgets for layout and containers:
/// - AuthFormCard: Card wrapper for auth forms with max width constraint
/// - BorderedContainer: Container with border styling
/// - BottomActionContainer: Bottom action bar with top border and safe area
/// - CardContent: Card with padding (has named constructor .standard())
/// - CategoryHeader: Header with icon, title, and count badge
/// **Consolidation**: Merged from 5 separate files (~224 LOC) for better maintainability

// ===== AUTH COMPONENTS =====

/// Reusable authentication form card component
/// Provides consistent styling for login/signup forms following design separation principles.
/// This widget encapsulates the visual presentation while keeping business logic in the view.
class AuthFormCard extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const AuthFormCard({
    super.key,
    required this.child,
    this.maxWidth = 400,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 400),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ===== CONTAINER COMPONENTS =====

/// Reusable bordered container component
/// Provides consistent styling for containers with borders.
/// Used for selection areas, content boxes, etc.
class BorderedContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  const BorderedContainer({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor ?? Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: child,
    );
  }
}

/// Reusable bottom action container component
/// Provides consistent styling for bottom action bars and containers.
/// Features a top border and background color with safe area handling.
class BottomActionContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsets? padding;

  const BottomActionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.backgroundBeige,
        border: Border(
          top: BorderSide(
            color: borderColor ?? AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

/// Reusable card content component
/// Provides consistent padding inside cards.
/// This component is allowed to use Padding since it's a reusable pattern.
class CardContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CardContent({
    super.key,
    required this.child,
    this.padding,
  });

  /// Standard padding card content
  const CardContent.standard({
    super.key,
    required this.child,
  }) : padding = const EdgeInsets.all(AppDimensions.spacingL);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
        child: child,
      ),
    );
  }
}

// ===== HEADER COMPONENTS =====

/// Reusable category header component
/// Provides consistent styling for category headers with icon, title, and count.
/// Used in menu previews, content lists, etc.
class CategoryHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Color? backgroundColor;
  final Color? textColor;

  const CategoryHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color: textColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: textColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
