import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
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
      // Plate line plus text, never a spinner (produktregler.md:163, B-18).
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: PlateLineMessage(
            message: loadingMessage ?? context.l10n.commonLoading,
          ),
        ),
      ),
    );
  }
}
