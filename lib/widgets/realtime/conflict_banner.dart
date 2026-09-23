/// BUT-1031: Banner widget that surfaces silent collaborative-edit conflict
/// resolutions to the user.
///
/// P3-U08: the anatomy is the drawn conflict banner (Komponentark v1:755-758):
/// a 1 px text.danger outline on surface.base, the triangle-alert glyph, a bold
/// title that names what has two versions, and body text saying who changed it
/// and that the user's version is still there. No channel is chosen here: which
/// entity gets a banner and which a snackbar is package 4's mounting work.
///
/// Last-write-wins used to be invisible — `ConflictResolutionModule.resolveConflict`
/// would pick a winner, the loser's edit would disappear, and no UI hinted at
/// the loss. This widget subscribes to [RealtimeSyncService.conflictStream] and
/// renders a non-blocking banner when an event arrives.
///
/// The widget is opt-in. Wrap it around (or sibling to) the collaborative
/// surface — recipe edit, menu plan, shopping list — to make conflicts visible
/// there. The infrastructure ships in this sprint; per-surface wiring is the
/// BUT-1031 follow-up.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';

/// Listens to the realtime sync service's [conflictStream] and renders the
/// conflict banner for the most recent event until the user dismisses it.
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

  /// The drawn title names what has two versions (Komponentark v1:756 draws
  /// "Två versioner av listan"). A shared recipe uses the own-recipe wording
  /// until PQ-02 decides what a non-owner's lost edit becomes.
  String _title(BuildContext context, ConflictEntity entity) {
    final l = context.l10n;
    return switch (entity) {
      ConflictEntity.recipeOwn ||
      ConflictEntity.recipeShared => l.conflictBannerTitleRecipe,
      ConflictEntity.weekMenu => l.conflictBannerTitleWeek,
    };
  }

  /// Who made the other change comes from the remote snapshot's cached
  /// display name, never from the collection or position.
  String _body(BuildContext context, ConflictEvent event) {
    final name = event.remoteValue.lastEditedByDisplayName.trim();
    return name.isEmpty
        ? context.l10n.conflictBannerBodyUnnamed
        : context.l10n.conflictBannerBody(name);
  }

  @override
  Widget build(BuildContext context) {
    final event = _activeEvent;
    if (event == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Komponentark v1:755-757. Outline and glyph are text.danger
    // (colorScheme.error: #9C3B23 light, #DE9078 dark, tokens.json:96-98),
    // title text.primary (onSurface: #24382C / #F5F4ED, tokens.json:54-56),
    // body text.body (#37453A / #F5F4ED, tokens.json:58-60), background
    // surface.base (surface: #F5F4ED / #17251D, tokens.json:104-106).
    final danger = cs.error;
    final bodyColor = AppModeColors.textBody(theme.brightness);

    // A new event is a new live region, so a screen reader hears each
    // conflict once and a rebuild of the same event stays silent.
    return KeyedSubtree(
      key: ObjectKey(event),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingS,
          ),
          child: Material(
            color: cs.surface,
            shape: Border.all(
              color: danger,
              width: AppDimensions.borderWidthStandard,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingModerate,
                AppDimensions.paddingM,
                AppDimensions.spacingXs,
                AppDimensions.paddingM,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.spacingXxs,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: danger,
                      size: AppDimensions.iconSize18,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingMs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(context, event.entity),
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXxs),
                        Text(
                          _body(context, event),
                          style: AppTextStyles.captionBase.copyWith(
                            color: bodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _onViewChange(event),
                    child: Text(context.l10n.commonView),
                  ),
                  IconButton(
                    tooltip: context.l10n.a11yConflictBannerDismiss,
                    icon: const Icon(Icons.close),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
