// lib/widgets/common/indicators/loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';

/// Configurable loading indicator with consistent styling.
/// Uses platform-adaptive activity indicator (Cupertino on iOS, Material on Android).
///
/// BUT-895: wraps the indicator in `Semantics(label:..., liveRegion: true)`
/// so screen-reader users know when async state changes. Defaults to the
/// localized `a11yLoading` string ("Loading" / "Laddar"); override
/// [semanticLabel] for more specific contexts (e.g. "Loading recipes").
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  /// Optional screen-reader override. Null = use `context.l10n.a11yLoading`.
  final String? semanticLabel;

  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth,
    this.padding,
    this.color,
    this.semanticLabel,
  });

  /// Small loading indicator for app bars and buttons
  const LoadingIndicator.small({
    super.key,
    this.color,
    this.semanticLabel,
  })  : size = AppDimensions.iconSizeS,
        strokeWidth = 2,
        padding = const EdgeInsets.all(AppDimensions.spacingL);

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size ?? AppDimensions.iconSizeM;
    final indicator = SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: AdaptiveActivityIndicator(
        radius: indicatorSize / 2,
        strokeWidth: strokeWidth ?? 3,
        color: color,
      ),
    );

    // Use `Localizations.of<AppLocalizations>` directly (not the
    // throwing-null-check `AppLocalizations.of`) so that widget tests
    // that pump LoadingIndicator without LocalizationsDelegates (a
    // common test scaffold) don't crash. Fallback to 'Loading' is the
    // English a11yLoading string.
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final labelled = Semantics(
      label: semanticLabel ?? l10n?.a11yLoading ?? 'Loading',
      liveRegion: true,
      child: indicator,
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: labelled,
      );
    }

    return labelled;
  }
}
