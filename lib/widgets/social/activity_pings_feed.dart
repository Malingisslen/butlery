import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

const int _kMaxItems = 5;
const Duration _kActivityRefreshInterval = Duration(minutes: 2);

class ActivityPingsFeed extends StatefulWidget {
  const ActivityPingsFeed({
    required this.groupId,
    this.pingService,
    this.activityRepository,
    this.friendsService,
    super.key,
  });

  final String groupId;
  final PingService? pingService;
  final ActivityEventRepository? activityRepository;
  final UnifiedFriendsService? friendsService;

  @override
  State<ActivityPingsFeed> createState() => _ActivityPingsFeedState();
}

class _ActivityPingsFeedState extends State<ActivityPingsFeed> {
  StreamSubscription<List<Ping>>? _pingSub;
  Timer? _activityRefreshTimer;

  List<Ping> _pings = const [];
  List<ActivityEvent> _activities = const [];
  bool _loading = true;

  PingService get _pingService =>
      widget.pingService ?? ServiceLocator.get<PingService>();

  ActivityEventRepository get _activityRepo =>
      widget.activityRepository ??
      ServiceLocator.get<ActivityEventRepository>();

  UnifiedFriendsService? get _friendsService =>
      widget.friendsService ?? ServiceLocator.tryGet<UnifiedFriendsService>();

  @override
  void initState() {
    super.initState();
    _subscribeToPings();
    _refreshActivity();
    _activityRefreshTimer = Timer.periodic(
      _kActivityRefreshInterval,
      (_) => _refreshActivity(),
    );
  }

  @override
  void didUpdateWidget(covariant ActivityPingsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _pingSub?.cancel();
      _subscribeToPings();
      _refreshActivity();
    }
  }

  @override
  void dispose() {
    _pingSub?.cancel();
    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  void _subscribeToPings() {
    _pingSub = _pingService.watchGroup(widget.groupId).listen(
      (pings) {
        if (!mounted) return;
        setState(() {
          _pings = pings.where((p) => !p.acknowledged).toList();
          _loading = false;
        });
      },
      onError: (Object e, StackTrace st) {
        AppLogger.warning('ActivityPingsFeed: ping stream error: $e');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  Future<void> _refreshActivity() async {
    final memberIds = _resolveGroupMemberIds();
    if (memberIds.isEmpty) {
      if (!mounted) return;
      setState(() => _activities = const []);
      return;
    }
    try {
      final events = await _activityRepo.fetchFriendActivity(
        friendIds: memberIds,
        // Oversample so the merge with pings still yields a full top-5.
        limit: _kMaxItems * 2,
      );
      if (!mounted) return;
      setState(() => _activities = events);
    } catch (e) {
      AppLogger.warning('ActivityPingsFeed: activity fetch failed: $e');
    }
  }

  /// Resolve the non-viewer member ids for the current group. Falls back to
  /// empty when the group isn't found — the feed then only renders pings.
  List<String> _resolveGroupMemberIds() {
    final friends = _friendsService;
    if (friends == null) return const [];
    final myId = friends.currentUserId;

    FriendCategory? group;
    for (final c in friends.categoriesList) {
      if (c.id == widget.groupId) {
        group = c;
        break;
      }
    }
    if (group == null) return const [];

    final ids = <String>{group.ownerId, ...group.friendUserIds};
    if (myId != null) ids.remove(myId);
    return ids.toList(growable: false);
  }

  /// Resolve a member profile by uid from the friends service cache. Returns
  /// null if the viewer doesn't have the person in their friends list.
  UserProfile? _profileFor(String uid) {
    final friends = _friendsService;
    if (friends == null) return null;
    for (final f in friends.friends) {
      if (f.uid == uid) return f;
    }
    return null;
  }

  Future<void> _acknowledge(Ping ping) async {
    try {
      await _pingService.acknowledge(
        groupId: ping.groupId,
        pingId: ping.id,
      );
    } catch (e) {
      AppLogger.warning('ActivityPingsFeed: acknowledge failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final items = _mergedItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(
          left: BorderSide(
            color: AppColors.forestGreen,
            width: 3,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _FeedRow(
              key: ValueKey(item.id),
              item: item,
              profileResolver: _profileFor,
              onAcknowledge: () => _acknowledge(item.ping!),
            ),
        ],
      ),
    );
  }

  /// Merge pings + activity into a single timeline, newest first, top 5.
  List<_FeedItem> _mergedItems() {
    final merged = <_FeedItem>[
      for (final p in _pings)
        _FeedItem.ping(
          id: 'ping-${p.id}',
          createdAt: p.createdAt,
          ping: p,
        ),
      for (final a in _activities)
        _FeedItem.activity(
          id: 'activity-${a.id}',
          createdAt: a.createdAt,
          activity: a,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (merged.length > _kMaxItems) {
      return merged.sublist(0, _kMaxItems);
    }
    return merged;
  }
}

/// Unified row model — a feed item is either a ping or an activity event.
/// Keeping this as a closed sum type (rather than a shared base class) lets
/// the render code pattern-match without introspection.
class _FeedItem {
  final String id;
  final DateTime createdAt;
  final Ping? ping;
  final ActivityEvent? activity;

  const _FeedItem._({
    required this.id,
    required this.createdAt,
    this.ping,
    this.activity,
  });

  factory _FeedItem.ping({
    required String id,
    required DateTime createdAt,
    required Ping ping,
  }) =>
      _FeedItem._(id: id, createdAt: createdAt, ping: ping);

  factory _FeedItem.activity({
    required String id,
    required DateTime createdAt,
    required ActivityEvent activity,
  }) =>
      _FeedItem._(id: id, createdAt: createdAt, activity: activity);

  bool get isPing => ping != null;
}

/// One row in the activity/pings feed. Fixed-height-ish, avatar left, text
/// middle, relative timestamp right.
class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.item,
    required this.profileResolver,
    required this.onAcknowledge,
    super.key,
  });

  final _FeedItem item;
  final UserProfile? Function(String uid) profileResolver;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actorId =
        item.isPing ? item.ping!.fromUserId : item.activity!.actorId;
    final profile = profileResolver(actorId);
    final actorName = profile?.displayName ??
        (item.isPing ? '?' : item.activity!.actorDisplayName);
    final primary = _composeLine(l10n, item, actorName);
    final suffix = item.isPing ? item.ping!.message : null;

    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(profile: profile, fallbackName: actorName),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textDark,
                    fontWeight: item.isPing ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (suffix != null && suffix.isNotEmpty)
                  Text(
                    '— "$suffix"',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMedium,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(
            _relativeLabel(context, item.createdAt),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );

    if (!item.isPing) return child;

    // Pings: tap anywhere on the row acknowledges.
    return InkWell(
      key: const Key('ping-row-ack'),
      onTap: onAcknowledge,
      child: child,
    );
  }

  String _composeLine(
    AppLocalizations l10n,
    _FeedItem item,
    String actorName,
  ) {
    if (item.isPing) {
      final p = item.ping!;
      switch (p.type) {
        case PingType.nudge:
          return l10n.pingNudgeFrom(actorName);
        case PingType.timerAlert:
          return l10n.pingTimerAlertFrom(actorName);
        case PingType.helpMe:
          return l10n.pingHelpMeFrom(actorName);
      }
    }

    final a = item.activity!;
    switch (a.type) {
      case ActivityEventType.addedIngredient:
        final ingredient = (a.extraData['ingredient'] as String?) ?? '';
        return l10n.activityAddedIngredient(actorName, ingredient);
      case ActivityEventType.startedCooking:
        return l10n.activityStartedCooking(actorName, a.recipeTitle);
      case ActivityEventType.cooked:
        return '$actorName ${l10n.feedActionCooked} ${a.recipeTitle}';
      case ActivityEventType.shared:
        return '$actorName ${l10n.feedActionShared} ${a.recipeTitle}';
      case ActivityEventType.pinged:
        // Should render via the _FeedItem.ping path — fall through safety net.
        return l10n.pingNudgeFrom(actorName);
    }
  }

  String _relativeLabel(BuildContext context, DateTime at) {
    // Clamp clock-drift (friend's device ahead of ours).
    final clamped = at.isAfter(DateTime.now()) ? DateTime.now() : at;
    return TimeAgoFormatter.standard(clamped);
  }
}

/// Square avatar — matches `FamilyPresenceBar` design language. Image when
/// we have one, initials fallback otherwise.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.profile,
    required this.fallbackName,
  });

  final UserProfile? profile;
  final String fallbackName;

  static const double _size = 32.0;

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: _size,
        height: _size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final label = profile?.initials ?? _deriveInitials(fallbackName);
    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.forestGreenLight),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  static String _deriveInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }
}
