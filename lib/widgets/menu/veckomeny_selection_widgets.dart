/// Presentational widgets extracted from veckomeny_view (BUT-1258): the
/// view-mode switch, the live cooking-session presence card, and the
/// generating panel.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';

/// View-mode toggle for the Veckomeny screen output.
enum VeckomenyViewMode { lista, kalender }

/// The list/calendar tabs under the week menu's root bar: underlined text
/// tabs, as Hem's "Alla recept | Kokböcker" are (Malin 2026-10-12).
class VeckomenyViewModeToggle extends StatelessWidget {
  final VeckomenyViewMode mode;
  final ValueChanged<VeckomenyViewMode> onSelect;

  const VeckomenyViewModeToggle({
    super.key,
    required this.mode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return UnderlineTabs<VeckomenyViewMode>(
      values: VeckomenyViewMode.values,
      labelOf: (value) => switch (value) {
        VeckomenyViewMode.lista => context.l10n.weeklyMenuToggleList,
        VeckomenyViewMode.kalender => context.l10n.weeklyMenuToggleCalendar,
      },
      selected: mode,
      onChanged: onSelect,
    );
  }
}

/// BUT-408: live cooking-session presence card for the user's groups.
///
/// Merges presence streams across every FriendCategory the user belongs to and
/// hides itself entirely when no friend is cooking. Owns its own
/// [CookingSessionStreamHolder] so the subscription lifecycle stays scoped to
/// this widget.
class VeckomenyCookingSessionCard extends StatefulWidget {
  const VeckomenyCookingSessionCard({super.key});

  @override
  State<VeckomenyCookingSessionCard> createState() =>
      _VeckomenyCookingSessionCardState();
}

class _VeckomenyCookingSessionCardState
    extends State<VeckomenyCookingSessionCard> {
  final UnifiedFriendsService _friendsService =
      ServiceLocator.get<UnifiedFriendsService>();
  final CookingSessionStreamHolder _sessionsHolder =
      CookingSessionStreamHolder();

  @override
  void dispose() {
    _sessionsHolder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final module = ServiceLocator.tryGet<CookingSessionModule>();
    final userId = _friendsService.currentUserId;
    if (module == null || userId == null) return const SizedBox.shrink();

    final groups = _friendsService.categoriesList
        .where(
          (FriendCategory c) =>
              c.ownerId == userId || c.friendUserIds.contains(userId),
        )
        .map((g) => g.id)
        .toList(growable: false);
    if (groups.isEmpty) return const SizedBox.shrink();

    _sessionsHolder.refresh(module, groups, userId);
    final stream = _sessionsHolder.stream;
    // `groups` is provably non-empty here (the `groups.isEmpty` guard above
    // short-circuits), and `refresh` only leaves `stream` null for an empty
    // group list — so this is never null at this point. Assert it instead of
    // silently hiding, so a future change to the holder's null contract trips
    // a test rather than vanishing the card with no signal.
    assert(
      stream != null,
      'CookingSessionStreamHolder.stream must be non-null for a non-empty '
      'group list',
    );

    return StreamBuilder<List<CookingSession>>(
      stream: stream,
      builder: (_, snapshot) {
        final sessions = snapshot.data ?? const <CookingSession>[];
        return CookingSessionCard(sessions: sessions);
      },
    );
  }
}

/// The week while it is being planned: the plate line with text, never the
/// animated pea pod (ux-beslut.json D-03; produktregler.md:163, :304;
/// beslutslogg.md:25 B-18).
///
/// Skarmar v12 del 1 #veckogenererarpanel draws a panel with a 1 px
/// text.primary border: the step in 13/700, the indeterminate plate line,
/// and a line on what is being done. There is no "Fortsätt i bakgrunden":
/// D-03 removes the long-wait state, so generation stays here until it is
/// done. The line is a live region, so the status is read without moving
/// focus (#veckogenererarpanel: "Statusen annonseras utan fokusbyte").
///
/// After [slowAfter] (6 s) the status line changes to "Det tar längre tid än
/// vanligt" in the same view (flows-roles-budget.md:33;
/// fas2/block288-uxfrysning.json TR::FLOW::01::genererar::6-10-s REQUIRED;
/// ux-beslut.json D-03, "$bevarat").
class VeckomenyGeneratingOverlay extends StatefulWidget {
  const VeckomenyGeneratingOverlay({
    super.key,
    this.slowAfter = const Duration(seconds: 6),
  });

  /// When the status line says the planning takes longer than usual.
  final Duration slowAfter;

  @override
  State<VeckomenyGeneratingOverlay> createState() =>
      _VeckomenyGeneratingOverlayState();
}

class _VeckomenyGeneratingOverlayState
    extends State<VeckomenyGeneratingOverlay> {
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = context.l10n.weekMenuPlanningTitle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      // text.primary: ink on light, paper on dark (onSurface).
      decoration: BoxDecoration(border: Border.all(color: cs.onSurface)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              title,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space12),
          PlateLine(semanticLabel: title),
          const SizedBox(height: AppDimensions.space12),
          Semantics(
            liveRegion: true,
            child: Text(
              _slow
                  ? context.l10n.weekMenuPlanningSlow
                  : context.l10n.menuGeneratingSubtitle,
              key: const ValueKey('veckomeny-generating-status'),
              // #veckogenererarpanel draws the status in text.body (#37453A
              // light, #F5F4ED dark). No scheme slot carries text.body; the
              // dark value is onSurface exactly and light is the nearer ink.
              style: AppTextStyles.captionBase.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// P6-U01: the week menu's Generera, switched off offline with the reason
/// in text.
///
/// produktregler.md:1131 and flows-roles-budget.md:34 ("genererar | offline
/// | avbrutet + banner, tidigare vecka orörd"; fas2/block288-uxfrysning.json
/// TR::FLOW::01::genererar::offline REQUIRED): offline does not lock the
/// calendar, only generation is switched off, and the reason is said in
/// plain words next to the switched-off button, never by the button's look
/// alone. The offline banner above the view (LayoutComponents
/// .offlineIndicator) is the "banner" of the flow.
///
/// While the week is planned it keeps its shape and gets the plate line along
/// its bottom edge.
class VeckomenyGenerateButton extends StatelessWidget {
  const VeckomenyGenerateButton({
    super.key,
    required this.label,
    required this.busy,
    required this.busyLabel,
    required this.onGenerate,
    this.reasonBelow = true,
    this.expand = false,
  });

  final String label;
  final bool busy;
  final String busyLabel;

  /// Null while there is no prompt to generate from.
  final VoidCallback? onGenerate;

  /// Whether the offline reason stands under the button. A button that sits
  /// beside a field leaves the reason to the row, which gives it the full
  /// width ([VeckomenyOfflineReason]).
  final bool reasonBelow;

  /// The button takes the full width, under a field that has no room for it.
  final bool expand;

  /// The reason line under the switched-off button, for tests.
  static const Key offlineReasonKey = VeckomenyOfflineReason.reasonKey;

  @override
  Widget build(BuildContext context) {
    return VeckomenyConnectivity(
      builder: (context, isOnline) {
        final button = Semantics(
          identifier: 'btn-generate-menu',
          child: FormButton(
            label: label,
            busy: busy,
            busyLabel: busyLabel,
            onPressed: isOnline ? onGenerate : null,
            expand: expand,
            // Beside a field the style's full-width minimum has no room.
            minimumSize: reasonBelow
                ? null
                : const Size(0, AppDimensions.minTouchTarget),
          ),
        );
        if (isOnline || !reasonBelow) return button;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            button,
            const SizedBox(height: AppDimensions.space8),
            const VeckomenyOfflineReason(),
          ],
        );
      },
    );
  }
}

/// Why Generera is switched off offline, in words (P6-U01).
class VeckomenyOfflineReason extends StatelessWidget {
  const VeckomenyOfflineReason({super.key});

  static const Key reasonKey = ValueKey<String>(
    'veckomeny-generate-offline-reason',
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        context.l10n.menuGenerateOfflineReason,
        key: reasonKey,
        textAlign: TextAlign.center,
        // text.secondary: #5B6959 light, its dark value in dark
        // (onSurfaceVariant in both schemes).
        style: AppTextStyles.captionBase.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// P6-U01: rebuilds with whether the app is online, read from
/// [OfflineService.isOnline] (lib/services/offline_service.dart). Without a
/// registered service it reads as online, as the offline banner does.
class VeckomenyConnectivity extends StatelessWidget {
  const VeckomenyConnectivity({super.key, required this.builder});

  final Widget Function(BuildContext context, bool isOnline) builder;

  /// Whether the app is online right now.
  static bool isOnlineNow() =>
      ServiceLocator.tryGet<OfflineService>()?.isOnline ?? true;

  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.tryGet<OfflineService>();
    if (service == null) return builder(context, true);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) => builder(context, service.isOnline),
    );
  }
}
