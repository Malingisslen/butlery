// lib/views/more/more_view.dart
//
// The shell's fourth tab, the hub for everything that is not in the bottom
// bar (Mer, omtänkt, approved by Malin 2026-10-10; mockup
// https://claude.ai/artifact/DgYQzTN2nmHNRMQoJZEWiM). On top the user's own
// profile, then a band while changes wait to sync, then four sections. There
// is no Inställningar level and no profile menu behind an avatar: what they
// held lives under the four rows of Konto & app.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/social_components/social_avatar_components.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

class MoreView extends StatelessWidget {
  const MoreView({super.key});

  /// The key of the row that opens [route]. Identity is the destination.
  static Key rowKey(String route) => ValueKey<String>('more-row-$route');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    ButleryListRow row(
      String label,
      String route, {
      String? subtitle,
      int count = 0,
      String? countLabel,
    }) => ButleryListRow(
      key: rowKey(route),
      identifier: 'more-row-$route',
      label: label,
      subtitle: subtitle,
      count: count,
      countLabel: countLabel,
      onTap: () => Navigator.of(context).pushNamed(route),
    );

    return Scaffold(
      // Mönster 1 · Rotnivå (Komponentark v1:60-68).
      appBar: ButleryTopBar.rot(title: l10n.moreTitle),
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Max line length holds on a wide screen (produktregler.md:1050).
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: ButleryTopBar.sideMargin(context),
                vertical: AppDimensions.spacingSm,
              ),
              children: [
                const _ProfileRow(),
                // "Mer → Väntar på synk" (produktregler.md), only while
                // something is waiting.
                QueueCountsBuilder(
                  builder: (context, counts) => counts.waiting > 0
                      ? _SyncBand(
                          waiting: counts.waiting,
                          needsUser: counts.needsUser,
                        )
                      : const SizedBox.shrink(),
                ),
                ButleryListSection(
                  title: l10n.moreSectionTogether,
                  rows: [
                    row(l10n.moreNotifications, Routes.notifications),
                    row(l10n.messagingTitle, Routes.messages),
                    // BUT-2306: a friend request was only visible inside
                    // Vänner & grupper, under "Hitta vänner".
                    _IncomingRequestsCount(
                      builder: (context, count) => row(
                        l10n.socialFriendsAndGroups,
                        Routes.friends,
                        count: count,
                        countLabel: l10n.syncQueueNeedsYouHeader(count),
                      ),
                    ),
                    row(l10n.profileSharedWithMe, Routes.shared),
                  ],
                ),
                ButleryListSection(
                  title: l10n.moreSectionHousehold,
                  rows: [
                    row(l10n.moreFamily, Routes.settingsFamily),
                    row(l10n.moreAllergens, Routes.settingsAllergens),
                  ],
                ),
                ButleryListSection(
                  title: l10n.moreSectionKitchen,
                  rows: [
                    row(l10n.morePersonalTags, Routes.settingsPersonalTags),
                    row(l10n.moreCollectionStats, Routes.collectionStats),
                    row(l10n.trashTitle, Routes.settingsTrash),
                  ],
                ),
                ButleryListSection(
                  title: l10n.moreSectionAppAccount,
                  rows: [
                    row(
                      l10n.settingsAccountAreaTitle,
                      Routes.settingsAccount,
                      subtitle: l10n.settingsAccountAreaSubtitle,
                    ),
                    row(
                      l10n.settingsPrivacyAreaTitle,
                      Routes.settingsPrivacy,
                      subtitle: l10n.settingsPrivacyAreaSubtitle,
                    ),
                    row(
                      l10n.settingsAppTitle,
                      Routes.settings,
                      subtitle: l10n.settingsAppSubtitle,
                    ),
                    row(
                      l10n.settingsHelpTitle,
                      Routes.settingsHelp,
                      subtitle: l10n.settingsHelpSubtitle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's avatar and name, leading to Profil. Without a user service (a
/// test host) it shows the fallback name.
class _ProfileRow extends StatefulWidget {
  const _ProfileRow();

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  UserService? _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.tryGet<UserService>();
  }

  @override
  Widget build(BuildContext context) {
    final users = _userService;
    if (users == null) return _build(context, null);
    return ListenableBuilder(
      listenable: users,
      builder: (context, _) => _build(context, users),
    );
  }

  Widget _build(BuildContext context, UserService? users) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final name = users?.currentDisplayName;
    final shownName = (name == null || name.trim().isEmpty)
        ? l10n.moreProfileFallbackName
        : name;
    return Semantics(
      container: true,
      button: true,
      identifier: 'more-row-${Routes.profileEdit}',
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          key: MoreView.rowKey(Routes.profileEdit),
          onTap: () => Navigator.of(context).pushNamed(Routes.profileEdit),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingL,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SocialAvatarComponents.avatar(
                    user: users?.currentUserProfile,
                    displayName: shownName,
                    size: ImageSize.medium,
                    announceName: false,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shownName,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        l10n.moreProfileSubtitle,
                        style: AppTextStyles.captionBase.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: ButleryIcon(
                    ButleryIcons.chevronRight,
                    color: cs.onSurfaceVariant,
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

/// "N ändringar väntar på synk" on surface.raised, with a count only when
/// some of them need the user (PQ-04 = B).
class _SyncBand extends StatelessWidget {
  const _SyncBand({required this.waiting, required this.needsUser});

  final int waiting;
  final int needsUser;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
      child: Semantics(
        container: true,
        button: true,
        identifier: 'more-row-${Routes.syncQueue}',
        value: needsUser > 0 ? l10n.syncQueueNeedsYouHeader(needsUser) : null,
        child: Material(
          color: cs.surfaceContainerHighest,
          borderRadius: radius,
          child: PressFill(
            surface: PressSurface.raised,
            child: InkWell(
              key: MoreView.rowKey(Routes.syncQueue),
              borderRadius: radius,
              onTap: () => Navigator.of(
                context,
              ).pushNamed(Routes.syncQueue, arguments: l10n.moreTitle),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: ButleryIcon(
                          ButleryIcons.refreshCw,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm + 2),
                      Expanded(
                        child: Text(
                          l10n.moreSyncBand(waiting),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (needsUser > 0) ...[
                        ExcludeSemantics(
                          child: SaffronCount(count: needsUser),
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                      ],
                      ExcludeSemantics(
                        child: ButleryIcon(
                          ButleryIcons.chevronRight,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds with the number of friend requests waiting for the user, live.
/// Without the friends service (a test host) it stays at zero.
class _IncomingRequestsCount extends StatefulWidget {
  const _IncomingRequestsCount({required this.builder});

  final Widget Function(BuildContext context, int count) builder;

  @override
  State<_IncomingRequestsCount> createState() => _IncomingRequestsCountState();
}

class _IncomingRequestsCountState extends State<_IncomingRequestsCount> {
  StreamSubscription<Object?>? _subscription;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    final friends = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (friends == null) return;
    _count = friends.incomingRequests.length;
    _subscription = friends.stateStream.listen(
      (_) {
        final count = friends.incomingRequests.length;
        if (mounted && count != _count) setState(() => _count = count);
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _count);
}
