import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/social/ping_compose_sheet.dart';

/// Max avatars rendered before overflow chip takes over.
const int _kMaxVisibleAvatars = 5;

/// Size of each avatar (square edge length, logical pixels).
const double _kAvatarSize = 40.0;

/// Size of the overlay online indicator (small square dot).
const double _kOnlineDotSize = 10.0;

/// Horizontal presence row. Hides itself when no group member is online.
class FamilyPresenceBar extends StatelessWidget {
  const FamilyPresenceBar({
    this.groupId,
    this.onlineUserIdsStream,
    this.memberProfiles,
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

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveMembers(context);
    if (resolved.isEmpty) return const SizedBox.shrink();

    final stream = onlineUserIdsStream ?? _composePresenceStream(resolved);
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<Set<String>>(
      stream: stream,
      initialData: const <String>{},
      builder: (context, snapshot) {
        final onlineIds = snapshot.data ?? const <String>{};
        final online = resolved
            .where((p) => onlineIds.contains(p.uid))
            .toList(growable: false);
        if (online.isEmpty) return const SizedBox.shrink();
        return _PresenceRow(members: online, groupId: groupId);
      },
    );
  }

  /// Resolve the candidate member profiles this bar should observe.
  ///
  /// Priority:
  /// 1. Test injection via [memberProfiles]
  /// 2. Scoped to [groupId] members (when provided)
  /// 3. Union of every [FriendCategory] the user belongs to
  List<UserProfile> _resolveMembers(BuildContext context) {
    if (memberProfiles != null) return memberProfiles!;

    final friends = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (friends == null) return const <UserProfile>[];

    final currentUserId = friends.currentUserId;
    if (currentUserId == null) return const <UserProfile>[];

    final groups = friends.categoriesList.where((FriendCategory c) {
      if (groupId != null) return c.id == groupId;
      return c.ownerId == currentUserId ||
          c.friendUserIds.contains(currentUserId);
    });

    // Union-dedupe the member ids across matching groups, excluding the
    // viewer themselves (presence bar is for *others*).
    final seen = <String>{};
    final ids = <String>[];
    for (final g in groups) {
      for (final id in g.friendUserIds) {
        if (id == currentUserId) continue;
        if (seen.add(id)) ids.add(id);
      }
      if (g.ownerId != currentUserId && seen.add(g.ownerId)) {
        ids.add(g.ownerId);
      }
    }
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
        color: AppColors.cream,
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
        child: SizedBox(
          width: _kAvatarSize,
          height: _kAvatarSize,
          child: Stack(
            children: [
              Positioned.fill(child: _AvatarThumb(profile: profile)),
              const Positioned(
                right: 0,
                bottom: 0,
                child: _OnlineDot(),
              ),
            ],
          ),
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

/// Avatar image (if we have a URL) falling back to a cream square with the
/// member's initials. Square edges per design system.
class _AvatarThumb extends StatelessWidget {
  const _AvatarThumb({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: _kAvatarSize,
        height: _kAvatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _InitialsSquare(profile: profile),
      );
    }
    return _InitialsSquare(profile: profile);
  }
}

/// Initials fallback — square (no BorderRadius), forestGreenLight ground.
class _InitialsSquare extends StatelessWidget {
  const _InitialsSquare({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.forestGreenLight,
      ),
      child: Center(
        child: Text(
          profile.initials,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Tiny square green dot indicating the member is currently online.
///
/// The task spec says a *static* dot is fine, so we intentionally do NOT
/// pulse even when animations are allowed — that keeps the bar quiet and
/// avoids fighting with the cooking-session card (which does pulse and is
/// the primary eye-catcher in the same region).
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kOnlineDotSize,
      height: _kOnlineDotSize,
      decoration: const BoxDecoration(
        color: AppColors.forestGreen,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.cream, width: 1.5),
        ),
      ),
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
    final label = context.l10n.familyPresenceOverflow(count);
    return Container(
      width: _kAvatarSize,
      height: _kAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        border: Border.all(
          color: AppColors.forestGreen.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.forestGreenDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
