import 'package:flutter/material.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// Error scaffold consolidating patterns from 15+ files
class ErrorScaffold extends StatelessWidget {
  final String? title;
  final String errorMessage;
  final VoidCallback? onRetry;
  final bool showBackButton;
  final List<Widget>? actions;

  const ErrorScaffold({
    super.key,
    this.title,
    this.errorMessage = AppStrings.genericError,
    this.onRetry,
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
              Icon(
                Icons.error_outline,
                size: iconSize,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: spacing),
              Text(
                errorMessage,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: spacing * 1.5),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text(AppStrings.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
