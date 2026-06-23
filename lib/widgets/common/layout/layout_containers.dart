import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Consolidated layout container widgets.

/// Authentication form card with max width constraint.
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

/// Container with border styling.
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

/// Bottom action bar with top border and safe area.
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
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

/// Card with consistent padding.
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

/// Category header with icon, title, and count badge.
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
        color:
            backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color:
                textColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.titleBold.copyWith(
                color:
                    textColor ??
                    Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius10),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.badge.copyWith(
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
