/// Presentational widgets extracted from veckomeny_view (BUT-1258): the
/// view-mode toggle, the live cooking-session presence card, and the
/// generating loading overlay. Pure structural split — no behaviour change.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';

/// View-mode toggle for the Veckomeny screen output.
enum VeckomenyViewMode { lista, kalender }

/// Segmented list/calendar toggle shown in the Veckomeny header.
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
          border: Border.all(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleButton(
              context,
              label: context.l10n.weeklyMenuToggleList,
              active: mode == VeckomenyViewMode.lista,
              onTap: () => onSelect(VeckomenyViewMode.lista),
            ),
            _toggleButton(
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

  Widget _toggleButton(
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
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: active ? cs.surface : Colors.transparent,
          child: Text(
            label.toLowerCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: active ? cs.onPrimaryContainer : cs.onPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
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
        .where((FriendCategory c) =>
            c.ownerId == userId || c.friendUserIds.contains(userId))
        .map((g) => g.id)
        .toList(growable: false);
    if (groups.isEmpty) return const SizedBox.shrink();

    _sessionsHolder.refresh(module, groups, userId);
    final stream = _sessionsHolder.stream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<CookingSession>>(
      stream: stream,
      builder: (_, snapshot) {
        final sessions = snapshot.data ?? const <CookingSession>[];
        return CookingSessionCard(sessions: sessions);
      },
    );
  }
}

/// UI Redesign: branded full-screen overlay shown while a menu is generating.
class VeckomenyGeneratingOverlay extends StatelessWidget {
  const VeckomenyGeneratingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return PeaLoadingOverlay(
      message: context.l10n.menuGeneratingOverlay,
      subtitle: context.l10n.menuGeneratingSubtitle,
    );
  }
}
