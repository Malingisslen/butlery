/// Presentational widgets extracted from veckomeny_view (BUT-1258): the
/// view-mode tabs, the live cooking-session presence card, and the
/// generating panel.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';

/// View-mode toggle for the Veckomeny screen output.
enum VeckomenyViewMode { lista, kalender }

/// The list/calendar tab row under the week menu's root bar.
///
/// Skarmar v12 del 1 #veckomeny and #tomvecka draw it as two tabs under the
/// title, "Lista" and "Kalender": the chosen one 13/700 in text.primary with
/// a 3 px saffron line under it, the other 13/600 in text.secondary, and a
/// hairline in border.subtle under the row. The saffron line is the plate
/// line's "vald flik" (Komponentark v1:844), so it is the token
/// progressIndicator: #CE7C1E in light and dark. Each tab is at least 48 dp
/// tall and carries the focus ring (Grafisk manual v6:381; tokens.json:485-492).
class VeckomenyViewModeToggle extends StatelessWidget
    implements PreferredSizeWidget {
  final VeckomenyViewMode mode;
  final ValueChanged<VeckomenyViewMode> onSelect;

  const VeckomenyViewModeToggle({
    super.key,
    required this.mode,
    required this.onSelect,
  });

  /// The drawn underline under the chosen tab (#veckomeny: `height:3px`).
  static const double indicatorHeight = 3;

  /// The underline's key, for tests.
  static const Key indicatorKey = ValueKey<String>(
    'veckomenyViewModeToggle.indicator',
  );

  @override
  Size get preferredSize =>
      const Size.fromHeight(ButleryControlFocus.minSize + 1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ButleryTopBar.sideMargin(context),
      ),
      child: DecoratedBox(
        // border.subtle: #CCD1C2 light, rgba(245,244,237,0.18) dark
        // (tokens.json border.subtle; outlineVariant in both schemes).
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          spacing: AppDimensions.spacingMd,
          children: [
            _tab(
              context,
              label: context.l10n.weeklyMenuToggleList,
              active: mode == VeckomenyViewMode.lista,
              onTap: () => onSelect(VeckomenyViewMode.lista),
            ),
            _tab(
              context,
              label: context.l10n.weeklyMenuToggleCalendar,
              active: mode == VeckomenyViewMode.kalender,
              onTap: () => onSelect(VeckomenyViewMode.kalender),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yWeeklyMenuViewModeToggle(label),
      button: true,
      selected: active,
      excludeSemantics: true,
      child: ButleryControlFocus(
        child: InkWell(
          onTap: onTap,
          child: ButleryControlFocus.box(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXs,
                    vertical: AppDimensions.spacingL,
                  ),
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      // text.primary / text.secondary (onSurface /
                      // onSurfaceVariant), both modes.
                      color: active ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (active)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: SizedBox(
                      key: indicatorKey,
                      height: indicatorHeight,
                      child: ColoredBox(
                        color: context.butleryColors.progressIndicator,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
/// ux-beslut.json D-03, "$bevarat"). The drawn "Avbryt planeringen" is not
/// here yet: MenuViewModel has no way to stop a generation.
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
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingModerate,
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
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          PlateLine(semanticLabel: title),
          const SizedBox(height: AppDimensions.spacingL),
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
