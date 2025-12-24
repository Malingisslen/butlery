import 'package:flutter/material.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// Empty state scaffold consolidating patterns from 20+ files
class EmptyStateScaffold extends StatelessWidget {
  final String? title;
  final String emptyMessage;
  final IconData? emptyIcon;
  final VoidCallback? onAction;
  final String? actionText;
  final bool showBackButton;
  final List<Widget>? actions;

  const EmptyStateScaffold({
    super.key,
    this.title,
    this.emptyMessage = AppStrings.noItemsFound,
    this.emptyIcon = Icons.inbox_outlined,
    this.onAction,
    this.actionText,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final padding = AppDimensions.responsiveContentPadding(context);
    final iconSize = AppDimensions.responsiveIconSize(context, 64);
    final spacing = Breakpoints.valueFor(
      context: context,
      mobile: AppDimensions.spacingMd,
      tablet: AppDimensions.spacingLg,
      desktop: AppDimensions.spacingXl,
    );

    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      body: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emptyIcon != null) ...[
                Icon(
                  emptyIcon,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                SizedBox(height: spacing),
              ],
              Text(
                emptyMessage,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionText != null) ...[
                SizedBox(height: spacing * 1.5),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
