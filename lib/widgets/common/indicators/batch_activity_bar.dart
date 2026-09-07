// lib/widgets/common/indicators/batch_activity_bar.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';

/// Screen-level "something is running" bar, for work that outlives the control
/// that started it.
///
/// A spinner placed inside a button disappears whenever that button does, so on
/// a screen whose controls are conditional — a selection, a tab — a running job
/// can end up with nothing on screen saying so (BUT-2041). This bar belongs in
/// the screen's own column instead, gated on the job rather than on the
/// controls.
///
/// It owns its `liveRegion` and its label the way `LoadingIndicator` owns its
/// own, so a caller cannot mount the bar and forget the announcement.
class BatchActivityBar extends StatelessWidget {
  final bool active;

  /// Screen-reader override. Null = `context.l10n.a11yLoading`.
  final String? semanticLabel;

  const BatchActivityBar({
    super.key,
    required this.active,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    // The label rides the indicator's own `semanticsLabel`. `liveRegion` is
    // what makes a screen reader speak the change instead of waiting to be
    // asked.
    return Semantics(
      liveRegion: true,
      child: LinearProgressIndicator(
        semanticsLabel: semanticLabel ?? context.l10n.a11yLoading,
      ),
    );
  }
}
