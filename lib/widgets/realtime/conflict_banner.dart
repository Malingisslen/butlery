/// BUT-1031: Banner widget that surfaces silent collaborative-edit conflict
/// resolutions to the user.
///
/// Last-write-wins used to be invisible — `ConflictResolutionModule.resolveConflict`
/// would pick a winner, the loser's edit would disappear, and no UI hinted at
/// the loss. This widget subscribes to [RealtimeSyncService.conflictStream] and
/// renders a non-blocking [MaterialBanner] when an event arrives.
///
/// The widget is opt-in. Wrap it around (or sibling to) the collaborative
/// surface — recipe edit, menu plan, shopping list — to make conflicts visible
/// there. The infrastructure ships in this sprint; per-surface wiring is the
/// BUT-1031 follow-up.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';

/// Listens to the realtime sync service's [conflictStream] and renders a
/// [MaterialBanner] for the most recent event until the user dismisses it.
///
/// Place above the main content of a collaborative surface — the banner takes
/// vertical space when visible and collapses to nothing otherwise.
class ConflictBanner extends StatefulWidget {
  /// Optional override to scope the banner to a single document. When set,
  /// events for other documents are ignored.
  final String? filterDocId;

  /// Optional override for the "View what changed" action. When null, the
  /// banner opens its built-in [ConflictDiffView] for the active event
  /// (BUT-1163). Provide a callback only to intercept the navigation (e.g. a
  /// surface that wants to route differently or run a test spy).
  final VoidCallback? onViewChange;

  const ConflictBanner({
    super.key,
    this.filterDocId,
    this.onViewChange,
  });

  @override
  State<ConflictBanner> createState() => _ConflictBannerState();
}

class _ConflictBannerState extends State<ConflictBanner> {
  StreamSubscription<ConflictEvent>? _sub;
  ConflictEvent? _activeEvent;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    if (svc == null) return;
    _sub = svc.conflictStream.listen((event) {
      if (!mounted) return;
      final filter = widget.filterDocId;
      if (filter != null && event.docId != filter) return;
      setState(() {
        _activeEvent = event;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _dismiss() {
    setState(() {
      _activeEvent = null;
    });
  }

  /// Open the diff view for the active conflict. A caller-supplied
  /// [ConflictBanner.onViewChange] takes precedence so a surface can intercept;
  /// otherwise the banner navigates to its built-in [ConflictDiffView].
  void _onViewChange(ConflictEvent event) {
    final override = widget.onViewChange;
    if (override != null) {
      override();
      return;
    }
    ConflictDiffView.show(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final event = _activeEvent;
    if (event == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        decoration: BoxDecoration(
          color: context.butleryColors.warning.withValues(
            alpha: AppDimensions.opacityVeryLight,
          ),
          border: Border(
            left: BorderSide(
              color: context.butleryColors.warning,
              width: AppDimensions.borderWidthThick,
            ),
            bottom: BorderSide(
              color: context.butleryColors.warning.withValues(
                alpha: AppDimensions.opacityMediumLight,
              ),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.sync_problem,
              color: context.butleryColors.warning,
              size: AppDimensions.iconSizeM,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                context.l10n.conflictBannerMessage,
                style: TextStyle(
                  color: context.butleryColors.onWarningContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _onViewChange(event),
              child: Text(context.l10n.commonView),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            IconButton(
              tooltip: context.l10n.a11yConflictBannerDismiss,
              icon: const Icon(Icons.close),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
