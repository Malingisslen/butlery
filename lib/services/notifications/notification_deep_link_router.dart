/// Routes incoming push-notification taps to the right screen (BUT-641).
///
/// Cloud Functions stamps every outgoing FCM payload with `route`,
/// `targetId`, and `notificationType`. The client side has to:
/// 1. Pull those three fields out of the FCM `RemoteMessage.data` map.
/// 2. Translate `route` to a navigator action with `targetId` as argument.
/// 3. Be tolerant of legacy in-flight notifications without `route` — those
///    just open the app to the home screen instead of crashing.
/// 4. Log `notification_opened` analytics so push CTR is measurable.
///
/// **Why a separate class instead of a lambda in main.dart:** the lambda
/// approach (which is what BUT-641 replaces) has no analytics and no
/// missing-route handling. Putting the routing in a class lets us test it
/// without spinning up a full Flutter binding.
///
/// If a sender uses a string not in [NotificationRoutes.all], the router
/// falls back to home + logs `notification_payload_unknown_route` so the drift surfaces
/// in analytics.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/services/notifications/notification_routes.dart';

export 'package:butlery/services/notifications/notification_routes.dart';

/// Type of the test-seam callback that records a notification-open event
/// server-side. Production wiring resolves to the `recordNotificationOpened`
/// callable; tests inject a fake to assert the call shape without hitting
/// Firebase.
typedef RecordNotificationOpenedFn =
    Future<void> Function({
      required String notificationId,
      required String notificationType,
      String? route,
    });

/// Type of the test-seam callback that resolves a recipeId to a full
/// [Recipe]. Production wiring reads through the user-scoped
/// [RecipeRepository]; tests inject a fake to drive the navigation branches
/// without Firebase. Returns null when the recipe is missing or not
/// accessible to the current user (`read` is user-scoped).
typedef RecipeFetchFn = Future<Recipe?> Function(String id);

/// Handles a notification tap by navigating using [navigator] and logging
/// a `notification_opened` analytics event.
class NotificationDeepLinkRouter {
  final NavigatorState? Function() _navigatorResolver;
  final AnalyticsService? Function() _analyticsResolver;
  final RecordNotificationOpenedFn _recordOpened;
  final RecipeFetchFn _fetchRecipe;

  NotificationDeepLinkRouter({
    required NavigatorState? Function() navigatorResolver,
    required AnalyticsService? Function() analyticsResolver,
    RecordNotificationOpenedFn? recordOpened,
    RecipeFetchFn? fetchRecipe,
  }) : _navigatorResolver = navigatorResolver,
       _analyticsResolver = analyticsResolver,
       _recordOpened = recordOpened ?? _defaultRecordOpened,
       _fetchRecipe = fetchRecipe ?? _defaultFetchRecipe;

  /// Default production wiring — resolves a recipeId through the user-scoped
  /// [RecipeRepository]. Returns null for a recipe the current user can't
  /// read (e.g. another user's recipe referenced by a stale notification).
  static Future<Recipe?> _defaultFetchRecipe(String id) =>
      ServiceLocator.get<RecipeRepository>().read(id);

  /// Default production wiring — invokes the `recordNotificationOpened`
  /// callable in the europe-west1 region (where every Cloud Function for
  /// this project is deployed).
  ///
  /// Failure handling lives at the [handle] call site, not here, so the
  /// fire-and-forget contract holds for ANY [RecordNotificationOpenedFn]
  /// implementation (including injected test seams or future custom
  /// recorders). A rejected Future from any recorder is caught and logged;
  /// it does not propagate to the unhandled-async-error zone.
  static Future<void> _defaultRecordOpened({
    required String notificationId,
    required String notificationType,
    String? route,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('recordNotificationOpened');
    await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'notificationId': notificationId,
      'notificationType': notificationType,
      'route': ?route,
    });
  }

  /// Entry point matching `NotificationService.onNotificationTapped`.
  ///
  /// `route` may be null/empty — this happens for notifications queued
  /// before BUT-641 server-side rolled out. `data` carries `targetId`
  /// (under the `'id'` key, which is what `NotificationService` already
  /// stamps) plus, when present, the original `notificationType` for
  /// analytics attribution.
  void handle(String? route, Map<String, String?> data) {
    final navigator = _navigatorResolver();
    final analytics = _analyticsResolver();
    final targetId = data['id'];
    final notificationType = data['notificationType'];
    final notificationId = data['notificationId'];

    // Security-review C1: mirror the open to the server-side
    // `notification_opened_events` stream. Without this, CTR
    // aggregation in `suppressLowPerformers` reads 0 opens / N sends
    // and disables every notification type within a week.
    //
    // Dedup is server-side (deterministic doc id), so it's safe to
    // call this on every tap including duplicates.
    if (notificationId != null &&
        notificationId.isNotEmpty &&
        notificationType != null &&
        notificationType.isNotEmpty) {
      // Fire-and-forget — don't await before navigation. The callable
      // is region-pinned to europe-west1 so the round-trip latency
      // doesn't gate UI responsiveness.
      //
      // The try/catch lives HERE (call site), not inside the default
      // recorder, so failure-tolerance covers ANY injected
      // RecordNotificationOpenedFn — test seams and future custom
      // implementations alike. Without this, an injected recorder that
      // returned a rejected Future would emit an unhandled-async-error
      // to the zone instead of being silently logged.
      try {
        // ignore: discarded_futures
        _recordOpened(
          notificationId: notificationId,
          notificationType: notificationType,
          route: route,
        ).catchError((Object e) {
          // Open-events are CTR signal — we'd rather miss one than
          // break the user's deep-link tap. Log so a systemic outage
          // is visible in Crashlytics-equivalent.
          AppLogger.warning(
            '🔔 recordNotificationOpened failed (open not recorded): $e',
          );
        });
      } catch (e) {
        // Synchronous throw from a misbehaving recorder (rare, but
        // possible if e.g. an injected fn does input validation
        // synchronously). Treat the same as an async failure.
        AppLogger.warning(
          '🔔 recordNotificationOpened threw synchronously '
          '(open not recorded): $e',
        );
      }
    }

    if (route == null || route.isEmpty) {
      AppLogger.info(
        '🔔 Notification tap with no route — defaulting to home screen',
      );
      _logEvent(
        analytics,
        name: AnalyticsEvents.notificationPayloadMissingRoute,
        notificationType: notificationType,
      );
      _goHome(navigator);
      return;
    }

    if (!NotificationRoutes.all.contains(route)) {
      AppLogger.warning(
        '🔔 Notification tap with unknown route "$route" — defaulting to home',
      );
      _logEvent(
        analytics,
        name: AnalyticsEvents.notificationPayloadUnknownRoute,
        route: route,
        notificationType: notificationType,
      );
      _goHome(navigator);
      return;
    }

    _logEvent(
      analytics,
      name: AnalyticsEvents.notificationOpened,
      route: route,
      notificationType: notificationType,
    );

    if (navigator == null) {
      // Navigator not available yet — extremely early app start. The
      // analytics event still went out so push CTR is captured. Log loud
      // so we notice if this happens repeatedly (it shouldn't — main.dart
      // wires the router after navigator is built).
      AppLogger.warning(
        '🔔 Notification tap "$route" arrived before navigator was ready',
      );
      return;
    }

    switch (route) {
      case NotificationRoutes.recipe:
        if (_isNonEmpty(targetId)) {
          // The recipeDetail route requires a resolved Recipe object — an id
          // string alone routes to the error screen. Resolve it first.
          unawaited(_openRecipe(navigator, targetId!, scrollToComments: false));
        } else {
          // Without an id we can't resolve a recipe — go home rather than
          // pushing a broken detail screen.
          _goHome(navigator);
        }
        break;
      case NotificationRoutes.commentThread:
        if (_isNonEmpty(targetId)) {
          // Same recipeDetail route; the receiving widget reads
          // `scrollToComments` to auto-expand the thread.
          unawaited(_openRecipe(navigator, targetId!, scrollToComments: true));
        } else {
          _goHome(navigator);
        }
        break;
      case NotificationRoutes.friendRequest:
        navigator.pushNamed(Routes.friendRequests);
        break;
      case NotificationRoutes.cookingSession:
        // No Cloud Function emits this route yet, and `targetId` is a cooking
        // *session* id (not a recipeId), so it can't be resolved to the
        // Recipe that CookingModeView requires. Land on home rather than the
        // error screen until a real session→recipe resolver exists.
        _goHome(navigator);
        break;
      case NotificationRoutes.menuVoting:
        // Menu voting is a section of the realtime menu screen. The
        // realtime menu route accepts an optional initial-tab argument.
        navigator.pushNamed(Routes.realtimeMenu, arguments: data);
        break;
      case NotificationRoutes.winback:
        _goHome(navigator);
        break;
      case NotificationRoutes.myReports:
        _openDecision(navigator, AppealRole.reporter, targetId);
        break;
      case NotificationRoutes.myContentDecisions:
        _openDecision(navigator, AppealRole.owner, targetId);
        break;
      case NotificationRoutes.conversation:
        _pushWithIdOrHome(navigator, Routes.chat, targetId);
        break;
      case NotificationRoutes.friends:
        navigator.pushNamed(Routes.friends);
        break;
      case NotificationRoutes.group:
        _pushWithIdOrHome(navigator, Routes.groupDetail, targetId);
        break;
      case NotificationRoutes.home:
        _goHome(navigator);
        break;
    }
  }

  /// Resolves [id] to a full Recipe before navigating, because the
  /// recipeDetail route requires a Recipe (not an id string). Mirrors
  /// `DeepLinkHandler._handleRecipeLink`. Fire-and-forget: a fetch error or a
  /// null result (recipe missing, or owned by another user — `read` is
  /// user-scoped) falls back to home instead of the "page not found" screen.
  Future<void> _openRecipe(
    NavigatorState navigator,
    String id, {
    required bool scrollToComments,
  }) async {
    Recipe? recipe;
    try {
      recipe = await _fetchRecipe(id);
    } catch (e) {
      AppLogger.warning('🔔 Notification recipe fetch failed for $id: $e');
    }
    if (recipe == null) {
      AppLogger.info(
        '🔔 Notification recipe $id unavailable — falling back to home',
      );
      _goHome(navigator);
      return;
    }
    // The fetch is async — the user may have navigated away (navigator
    // unmounted) while it ran. Pushing on a detached navigator throws.
    if (!navigator.mounted) {
      AppLogger.info('🔔 Navigator unmounted after recipe fetch — skipping');
      return;
    }
    navigator.pushNamed(
      Routes.recipeDetail,
      arguments: <String, dynamic>{
        'recipe': recipe,
        'scrollToComments': scrollToComments,
      },
    );
  }

  /// The detail view when the push names a report, otherwise the list.
  void _openDecision(
    NavigatorState navigator,
    AppealRole role,
    String? reportId,
  ) {
    if (_isNonEmpty(reportId)) {
      navigator.pushNamed(
        Routes.decisionDetail,
        arguments: DecisionDetailArgs(role: role, reportId: reportId!),
      );
      return;
    }
    navigator.pushNamed(
      role == AppealRole.owner ? Routes.myContentDecisions : Routes.myReports,
    );
  }

  /// Both screens throw on a missing id, so without one the tap lands home.
  void _pushWithIdOrHome(NavigatorState navigator, String route, String? id) {
    if (_isNonEmpty(id)) {
      navigator.pushNamed(route, arguments: id);
    } else {
      _goHome(navigator);
    }
  }

  void _goHome(NavigatorState? navigator) {
    if (navigator == null || !navigator.mounted) return;
    AppActions.returnToHome(navigator);
  }

  void _logEvent(
    AnalyticsService? analytics, {
    required String name,
    String? route,
    String? notificationType,
  }) {
    if (analytics == null) return;
    final params = <String, Object>{};
    if (route != null) params['route'] = route;
    if (notificationType != null) params['notificationType'] = notificationType;
    // Best-effort — never let analytics errors propagate up over a real
    // navigation failure.
    try {
      analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      AppLogger.debug('NotificationDeepLinkRouter: analytics path failed: $e');
    }
  }

  static bool _isNonEmpty(String? s) => s != null && s.isNotEmpty;
}
