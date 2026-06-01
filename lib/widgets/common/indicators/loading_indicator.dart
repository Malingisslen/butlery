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

  /// Determinate progress in `0.0..1.0`. When non-null the indicator renders a
  /// determinate spinner (a Material `CircularProgressIndicator(value:)` on both
  /// platforms — Cupertino has no determinate spinner). When null it stays the
  /// indeterminate platform-adaptive indicator. (BUT-1173)
  final double? value;

  /// Track color behind a determinate arc. Only used when [value] is non-null.
  final Color? backgroundColor;

  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth,
    this.padding,
    this.color,
    this.semanticLabel,
    this.value,
    this.backgroundColor,
  });

  /// Small loading indicator for app bars and buttons
  const LoadingIndicator.small({
    super.key,
    this.color,
    this.semanticLabel,
  })  : size = AppDimensions.iconSizeS,
        strokeWidth = 2,
        padding = const EdgeInsets.all(AppDimensions.spacingL),
        value = null,
        backgroundColor = null;

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size ?? AppDimensions.iconSizeM;
    // Use Material's CircularProgressIndicator when determinate (value != null)
    // OR when a track [backgroundColor] is requested — Cupertino's indicator has
    // neither a determinate mode nor a track ring, so a backgroundColor would be
    // silently dropped on the adaptive path. Otherwise use the platform-adaptive
    // indeterminate indicator. (BUT-1173)
    final useMaterial = value != null || backgroundColor != null;
    final Widget spinner = useMaterial
        ? CircularProgressIndicator(
            value: value,
            strokeWidth: strokeWidth ?? 3,
            color: color,
            backgroundColor: backgroundColor,
          )
        : AdaptiveActivityIndicator(
            radius: indicatorSize / 2,
            strokeWidth: strokeWidth ?? 3,
            color: color,
          );
    final indicator = SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: spinner,
    );

    // Use `Localizations.of<AppLocalizations>` directly (not the
    // throwing-null-check `AppLocalizations.of`) so that widget tests
    // that pump LoadingIndicator without LocalizationsDelegates (a
    // common test scaffold) don't crash. Fallback to 'Loading' is the
    // English a11yLoading string.
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // Determinate: expose the percentage as a live region — this matches the
    // semantics Flutter's native CircularProgressIndicator(value:) emits, which
    // a static loading label would otherwise mask. ExcludeSemantics drops the
    // inner indicator's own auto-value so there is a single, correct node.
    // Indeterminate: announce the loading label. (BUT-1173)
    final Widget labelled = value != null
        ? Semantics(
            value: '${(value! * 100).round()}%',
            label: semanticLabel,
            liveRegion: true,
            child: ExcludeSemantics(child: indicator),
          )
        : Semantics(
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
