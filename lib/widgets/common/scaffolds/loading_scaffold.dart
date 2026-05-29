import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// Loading scaffold consolidating patterns from 25+ files
class LoadingScaffold extends StatelessWidget {
  final String? title;
  final String? loadingMessage;
  final bool showBackButton;
  final List<Widget>? actions;

  const LoadingScaffold({
    super.key,
    this.title,
    this.loadingMessage,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            SizedBox(height: spacing),
            Text(
              loadingMessage ?? context.l10n.commonLoading,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
