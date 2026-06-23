import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/retain_last_nonempty.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/social/ping_compose_sheet.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';

const int _kMaxVisibleAvatars = 5;
const double _kAvatarSize = 40.0;

/// Horizontal presence row. Hides itself when no group member is online.
///
/// StatefulWidget so that member resolution + the RTDB presence stream are
/// computed once in `initState` and re-computed only when [groupId] changes
/// (BUT-628). Previously a StatelessWidget rebuilt them on every ancestor
/// rebuild — for a user in 20 groups × 50 friends that's ~1000 iterations
/// + a fresh RTDB subscription per parent setState (route animations,
/// keyboard, etc.).
class FamilyPresenceBar extends StatefulWidget {
  const FamilyPresenceBar({
    this.groupId,
    this.onlineUserIdsStream,
    this.memberProfiles,
    this.isOffline,
    super.key,
  });

  /// When provided, the bar is scoped to the members of this group only.
  /// When null, the bar is a union across every [FriendCategory] the current
  /// user belongs to.
  final String? groupId;

  /// Test seam: inject a live stream of currently-online user ids so widget
  /// tests don't have to wire the presence service. When null, the widget
  /// composes its own stream from [PresenceService].
  final Stream<Set<String>>? onlineUserIdsStream;

  /// Test seam: inject the candidate member profiles so widget tests don't
  /// depend on [UnifiedFriendsService]. When null, the widget resolves this
  /// list from the friends service at build time.
  final List<UserProfile>? memberProfiles;

  /// Test seam: report whether the device is currently offline. When null, the
  /// widget resolves this from [OfflineService]. Drives the offline graceful-
  /// degradation behaviour (BUT-1360): while offline, the bar retains the last
  /// known set of online members instead of vanishing on an empty RTDB
  /// emission. While online it is ignored — live updates pass through.
  final bool Function()? isOffline;

  @override
  State<FamilyPresenceBar> createState() => _FamilyPresenceBarState();
}

class _FamilyPresenceBarState extends State<FamilyPresenceBar> {
  late List<UserProfile> _resolved;
  Stream<Set<String>>? _onlineIdsStream;

  @override
  void initState() {
    super.initState();
    _rebuildResolution();
  }

  @override
  void didUpdateWidget(covariant FamilyPresenceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final groupChanged = oldWidget.groupId != widget.groupId;
    final profilesChanged = !identical(
      oldWidget.memberProfiles,
      widget.memberProfiles,
    );
    final streamChanged = !identical(
      oldWidget.onlineUserIdsStream,
      widget.onlineUserIdsStream,
    );
    if (groupChanged || profilesChanged || streamChanged) {
      _rebuildResolution();
    }
  }

  void _rebuildResolution() {
    _resolved = _resolveMembers();
    final Stream<Set<String>>? source;
    if (widget.onlineUserIdsStream != null) {
      source = widget.onlineUserIdsStream;
    } else if (_resolved.isEmpty) {
      source = null;
    } else {
      source = _composePresenceStream(_resolved);
    }
    // BUT-1360: keep the bar showing the last-known online set when the device
    // drops offline (RTDB has no read cache and emits empty), instead of
    // abruptly vanishing. Online behaviour is unchanged — empties pass through.
    _onlineIdsStream = source?.transform(
      retainLastNonEmptyWhileOffline<Set<String>>(
        isEmpty: (ids) => ids.isEmpty,
        isOffline: _resolveIsOffline,
      ),
    );
  }

  bool _resolveIsOffline() {
    final injected = widget.isOffline;
    if (injected != null) return injected();
    final offline = ServiceLocator.tryGet<OfflineService>();
    // Absent service → treat as online so we never spuriously retain.
    return offline != null && !offline.isOnline;
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved.isEmpty) return const SizedBox.shrink();
    final stream = _onlineIdsStream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<Set<String>>(
      stream: stream,
      initialData: const <String>{},
      builder: (context, snapshot) {
        final onlineIds = snapshot.data ?? const <String>{};
        final online = _resolved
            .where((p) => onlineIds.contains(p.uid))
            .toList(growable: false);
        if (online.isEmpty) return const SizedBox.shrink();
        return _PresenceRow(members: online, groupId: widget.groupId);
      },
    );
  }

  /// Resolve the candidate member profiles this bar should observe.
  ///
  /// Priority:
  /// 1. Test injection via [memberProfiles]
  /// 2. Scoped to [groupId] members (when provided)
  /// 3. Union of every [FriendCategory] the user belongs to
  List<UserProfile> _resolveMembers() {
    if (widget.memberProfiles != null) return widget.memberProfiles!;

    final friends = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (friends == null) return const <UserProfile>[];

    final currentUserId = friends.currentUserId;
    if (currentUserId == null) return const <UserProfile>[];

    final groups = friends.categoriesList.where((FriendCategory c) {
      if (widget.groupId != null) return c.id == widget.groupId;
      return c.allMemberIds.contains(currentUserId);
    });

    // Union-dedupe member ids across matching groups, excluding the viewer.
    final ids = <String>{
      for (final g in groups) ...g.allMemberIds,
    }..remove(currentUserId);
    if (ids.isEmpty) return const <UserProfile>[];

    // Resolve profiles against the friends list. Friends we don't have a
    // profile for are silently dropped — presence on a stranger has no
    // avatar to render.
    final byId = {for (final f in friends.friends) f.uid: f};
    final profiles = <UserProfile>[];
    for (final id in ids) {
      final p = byId[id];
      if (p != null) profiles.add(p);
    }
    return profiles;
  }

  /// Compose a live stream of online user ids from [PresenceService].
  /// Returns null when the presence service isn't registered (e.g. during
  /// tests that don't provide one — they should use [onlineUserIdsStream]).
  Stream<Set<String>>? _composePresenceStream(List<UserProfile> members) {
    final presence = ServiceLocator.tryGet<PresenceService>();
    if (presence == null) return null;
    final ids = members.map((m) => m.uid).toList(growable: false);
    return presence.getMultiplePresenceStream(ids).map((map) {
      final online = <String>{};
      map.forEach((uid, p) {
        if (p.status == PresenceStatus.online) online.add(uid);
      });
      return online;
    });
  }
}

/// Internal render: horizontal row of square avatars + optional overflow
/// chip. Split out so the StreamBuilder builder stays tight.
class _PresenceRow extends StatelessWidget {
  const _PresenceRow({required this.members, this.groupId});

  final List<UserProfile> members;

  /// When non-null, long-pressing an avatar opens the ping compose sheet
  /// scoped to this group. When null (bar used without a group context),
  /// long-press is a no-op — the sheet can't resolve a target group.
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_kMaxVisibleAvatars).toList(growable: false);
    final overflow = members.length - visible.length;

    return Semantics(
      label: context.l10n.familyPresenceTitle,
      container: true,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in visible)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: _PresenceAvatar(profile: p, groupId: groupId),
                ),
              if (overflow > 0) _OverflowChip(count: overflow),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single online member's avatar. Square, with a green dot overlay on
/// the bottom-right edge.
///
/// Long-press opens the ping compose sheet for the member — only enabled
/// when a [groupId] is in scope (the presence bar in `mina_recept` /
/// `veckomeny` is group-ambiguous, so long-press is a no-op there).
class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar({required this.profile, this.groupId});

  final UserProfile profile;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final canPing = groupId != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // tap is reserved — long-press is the action
      onLongPress: canPing ? () => _openPingCompose(context) : null,
      child: Semantics(
        label: profile.displayName,
        button: true,
        child: UserAvatarWidgets.avatar(
          imageUrl: profile.avatarUrl,
          displayName: profile.displayName,
          explicitSize: _kAvatarSize,
          showStatus: true,
          isOnline: true,
        ),
      ),
    );
  }

  void _openPingCompose(BuildContext context) {
    showPingComposeSheet(
      context: context,
      groupId: groupId!,
      targetUserId: profile.uid,
    );
  }
}

/// "+N" square chip rendered when more than [_kMaxVisibleAvatars] members
/// are online. Kept visually subordinate to the real avatars.
class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = context.l10n.familyPresenceOverflow(count);
    return Container(
      width: _kAvatarSize,
      height: _kAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
