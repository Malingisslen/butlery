import 'package:clock/clock.dart';
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
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

class _ActivityPingsFeedState extends State<ActivityPingsFeed>
    with WidgetsBindingObserver {
  StreamSubscription<List<Ping>>? _pingSub;
  Timer? _activityRefreshTimer;

  List<Ping> _pings = const [];
  List<ActivityEvent> _activities = const [];
  Map<String, UserProfile> _profileById = const {};
  bool _loading = true;
  // True while the host app is in the foreground / visible. We pause the
  // 2-min activity poll while backgrounded (BUT-629) — overnight phones
  // would otherwise hit fetchFriendActivity 30×/hour for nothing.
  // Activity events from group members can arrive without an accompanying
  // ping (added ingredient, started cooking), so we intentionally keep the
  // periodic refresh rather than dropping it (ticket Option 2 would lose
  // those updates). On resume we fire one immediate refresh to re-prime
  // the feed.
  bool _foregrounded = true;

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
    WidgetsBinding.instance.addObserver(this);
    _subscribeToPings();
    _refreshActivity();
    _startActivityTimer();
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
    WidgetsBinding.instance.removeObserver(this);
    _pingSub?.cancel();
    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldRun = state == AppLifecycleState.resumed;
    if (shouldRun == _foregrounded) return;
    _foregrounded = shouldRun;
    if (shouldRun) {
      // Re-prime immediately on resume so the user doesn't see stale data
      // for up to 2 min, then resume the periodic cadence.
      _refreshActivity();
      _startActivityTimer();
    } else {
      _activityRefreshTimer?.cancel();
      _activityRefreshTimer = null;
    }
  }

  void _startActivityTimer() {
    _activityRefreshTimer?.cancel();
    _activityRefreshTimer = Timer.periodic(
      _kActivityRefreshInterval,
      (_) => _refreshActivity(),
    );
  }

  void _subscribeToPings() {
    _pingSub = _pingService.watchGroup(widget.groupId).listen(
      (pings) {
        if (!mounted) return;
        setState(() {
          _pings = pings.where((p) => !p.acknowledged).toList();
          _profileById = _buildProfileMap();
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
      setState(() {
        _activities = events;
        _profileById = _buildProfileMap();
      });
    } catch (e) {
      AppLogger.warning('ActivityPingsFeed: activity fetch failed: $e');
    }
  }

  // Empty list = group not found or service unavailable → feed renders pings
  // only.
  List<String> _resolveGroupMemberIds() {
    final friends = _friendsService;
    if (friends == null) return const [];
    final group =
        friends.categoriesList.firstWhereOrNull((c) => c.id == widget.groupId);
    if (group == null) return const [];
    final ids = group.allMemberIds.toSet();
    final myId = friends.currentUserId;
    if (myId != null) ids.remove(myId);
    return ids.toList(growable: false);
  }

  Map<String, UserProfile> _buildProfileMap() {
    final friends = _friendsService;
    if (friends == null) return const {};
    return {for (final f in friends.friends) f.uid: f};
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

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(
            color: cs.primary,
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
              profiles: _profileById,
              onAcknowledge: switch (item) {
                _PingItem(:final ping) => () => _acknowledge(ping),
                _ActivityItem() => null,
              },
            ),
        ],
      ),
    );
  }

  List<_FeedItem> _mergedItems() {
    final merged = <_FeedItem>[
      for (final p in _pings)
        _PingItem(id: 'ping-${p.id}', createdAt: p.createdAt, ping: p),
      for (final a in _activities)
        _ActivityItem(
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

// Sum type for the feed — a row is EITHER a ping OR an activity event.
// Sealed gives us exhaustive switches + no force-unwraps.
sealed class _FeedItem {
  const _FeedItem({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  String actorId();
}

class _PingItem extends _FeedItem {
  const _PingItem({
    required super.id,
    required super.createdAt,
    required this.ping,
  });

  final Ping ping;

  @override
  String actorId() => ping.fromUserId;
}

class _ActivityItem extends _FeedItem {
  const _ActivityItem({
    required super.id,
    required super.createdAt,
    required this.activity,
  });

  final ActivityEvent activity;

  @override
  String actorId() => activity.actorId;
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.item,
    required this.profiles,
    required this.onAcknowledge,
    super.key,
  });

  final _FeedItem item;
  final Map<String, UserProfile> profiles;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final profile = profiles[item.actorId()];
    final actorName = profile?.displayName ??
        switch (item) {
          _PingItem() => '?',
          _ActivityItem(:final activity) => activity.actorDisplayName,
        };
    final primary = _composeLine(l10n, item, actorName);
    final suffix = switch (item) {
      _PingItem(:final ping) => ping.message,
      _ActivityItem() => null,
    };

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
                    color: cs.onSurface,
                    fontWeight:
                        item is _PingItem ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (suffix != null && suffix.isNotEmpty)
                  Text(
                    '— "$suffix"',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
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
            _relativeLabel(item.createdAt),
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onAcknowledge == null) return child;
    return Semantics(
      label: context.l10n.a11yPingAcknowledge(actorName),
      button: true,
      child: InkWell(
        key: const Key('ping-row-ack'),
        onTap: onAcknowledge,
        child: child,
      ),
    );
  }

  String _composeLine(
    AppLocalizations l10n,
    _FeedItem item,
    String actorName,
  ) {
    return switch (item) {
      _PingItem(:final ping) => switch (ping.type) {
          PingType.nudge => l10n.pingNudgeFrom(actorName),
          PingType.timerAlert => l10n.pingTimerAlertFrom(actorName),
          PingType.helpMe => l10n.pingHelpMeFrom(actorName),
          // Newer client wrote a type we don't understand — render the
          // generic nudge copy rather than silently misattributing semantics.
          PingType.unknown => l10n.pingNudgeFrom(actorName),
        },
      _ActivityItem(:final activity) => switch (activity.type) {
          ActivityEventType.addedIngredient => l10n.activityAddedIngredient(
              actorName,
              (activity.extraData['ingredient'] as String?) ?? '',
            ),
          ActivityEventType.startedCooking => l10n.activityStartedCooking(
              actorName,
              activity.recipeTitle,
            ),
          ActivityEventType.cooked =>
            '$actorName ${l10n.feedActionCooked} ${activity.recipeTitle}',
          ActivityEventType.shared =>
            '$actorName ${l10n.feedActionShared} ${activity.recipeTitle}',
          // Should render via the _PingItem path — fall-through safety net.
          ActivityEventType.pinged => l10n.pingNudgeFrom(actorName),
        },
    };
  }

  String _relativeLabel(DateTime at) {
    final clamped = at.isAfter(clock.now()) ? clock.now() : at;
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
          errorBuilder: (_, __, ___) => _initials(context),
        ),
      );
    }
    return _initials(context);
  }

  Widget _initials(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = profile?.initials ?? _deriveInitials(fallbackName);
    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.inversePrimary),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onPrimary,
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
