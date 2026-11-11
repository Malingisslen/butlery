import 'package:clock/clock.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart'
    show GroupMenuParticipant, GroupWeeklyMenuPlan;
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/firebase_error_messages.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// The plan write a poll close has prepared but not yet performed (BUT-1925).
///
/// It must perform exactly one WRITE and no reads. Every read belongs in the
/// `_prepareWinnerFor…` that built it, because those run while the poll is
/// still open and a refusal there is recoverable — a read moved in here fails
/// after the one-way close instead, which gives up BUT-1928's guarantee with
/// every suite still green.
typedef PlanCommit = Future<void> Function();

/// Closing a poll and writing its winner into the plan (BUT-1923).
class PollResolutionOperations {
  final MessagingRepository _messagingRepository;
  final auth_repo.AuthRepository _authRepository;
  final BlockedUserFilter? Function() _blockFilter;
  final WeeklyMenuPlanService? Function() _weeklyPlanService;
  final GroupWeeklyMenuPlanService? Function() _groupPlanService;
  final UnifiedRecipeService? Function() _recipeService;

  PollResolutionOperations({
    required MessagingRepository messagingRepository,
    required auth_repo.AuthRepository authRepository,
    required BlockedUserFilter? Function() blockFilter,
    required WeeklyMenuPlanService? Function() weeklyPlanService,
    required GroupWeeklyMenuPlanService? Function() groupPlanService,
    required UnifiedRecipeService? Function() recipeService,
  }) : _messagingRepository = messagingRepository,
       _authRepository = authRepository,
       _blockFilter = blockFilter,
       _weeklyPlanService = weeklyPlanService,
       _groupPlanService = groupPlanService,
       _recipeService = recipeService;

  /// Single-message strip of blocked ballots. Fails OPEN toward the stored
  /// message (see [metadataWithoutVoters]); the display path and `closePoll`
  /// both call this, so the count on screen and the written winner agree.
  static Message stripBlockedBallots(Message message, Set<String> blockedIds) {
    final stripped = metadataWithoutVoters(message.metadata, blockedIds);
    if (identical(stripped, message.metadata)) return message;
    return message.copyWith(metadata: stripped);
  }

  /// Close a poll (creator only).
  ///
  /// When the closed poll has a winning option with a `recipeId`, auto-
  /// resolution appends that recipe to a current-week plan (today-anchored
  /// next empty slot) — which plan depends on the branch below. Winner = most
  /// votes; ties broken by chronological order (first option in the options
  /// list wins).
  ///
  /// Double-fire across concurrent callers is guarded by the CLOSE itself: the
  /// repository closes inside a transaction that refuses an already-closed
  /// poll, and this method writes the plan only when that transaction says it
  /// was the one that closed (BUT-1925). The pre-read below is a cheap skip,
  /// not the guard.
  ///
  /// Everything that can REFUSE runs before the close, so a refusal still
  /// leaves the poll open for a retry. The window that remains is the plan
  /// write: if it fails, the poll is closed with no dish planned, and the
  /// caller is told so through [PollClosedWithoutPlanException]. Malin's call,
  /// 2026-09-12, taken over stamping the plan entry with the poll's id.
  Future<void> closePoll({required String messageId}) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Pre-read the message to guard against double-resolution. If the poll
      // is already closed, another caller raced us — skip both the repo
      // close and the plan write.
      final existing = await _messagingRepository.getMessage(messageId);
      final existingPoll = _extractPoll(existing);
      if (existingPoll == null || existing == null) {
        // Message/poll gone — nothing to do.
        return;
      }
      if (existingPoll.isClosed) {
        AppLogger.debug('Poll $messageId already closed — skipping resolve');
        return;
      }

      // BUT-1908. Closing is a ONE-WAY door — nothing in the repository resets
      // `isClosed` — and a creator close writes a recipe into the household's
      // week. So it must never run on a tally that was not actually read.
      // Refusing leaves the poll OPEN and writes no plan, so a retry is safe.
      //
      // Reachable here only as `failed`: this method reads through
      // `getMessage`, whose list holds ONE message, so the cap is a no-op on
      // that path and a capped poll arrives marked `ok`. The capped case is
      // caught by `ChatViewModel.closePoll` and by the widget's own gate, which
      // are the two layers still holding the copy the user was shown. This
      // check is the backstop for a tally that errored.
      final hydration = PollVoteHydration.fromMetadata(existing.metadata);
      if (hydration.isUnread) {
        AppLogger.warning(
          'Refusing to close poll $messageId: votes were ${hydration.name}',
        );
        throw const PollCloseRefusedException(PollCloseRefusal.votesUnread);
      }

      // BUT-1909, and deliberately NOT the fail-open contract `_filterBlocked`
      // uses. There, an unknown block list serves an over-counted poll on
      // screen, which is recoverable. Here it would let a blocked person's
      // ballot decide the recipe that lands in other members' plan — so an
      // unresolvable block list refuses instead. Trust & Safety's condition.
      //
      // BUT-1926: an ABSENT filter refuses too. `tryGet` returning null is not
      // "nobody is blocked", it is "this build cannot tell" — the same state
      // the catch below refuses on — and skipping the branch on it made the
      // whole guard conditional on a service registration.
      final blockFilter = _blockFilter();
      if (blockFilter == null) {
        AppLogger.warning(
          'Refusing to close poll $messageId: no block filter registered',
        );
        throw const PollCloseRefusedException(
          PollCloseRefusal.blockListUnknown,
        );
      }
      final Set<String> blocked;
      try {
        // `requireBlockedIds`, NOT `currentBlockedIds`: the latter swallows a
        // failed lookup and returns an empty set, which would make this whole
        // branch dead code and fail OPEN on exactly the decision that cannot
        // be taken back. Raised as critical by the firebase-backend-security
        // gate, which also showed the test here was measuring its own mock.
        // BUT-1917: BOTH directions, unioned, and both server-only. The
        // display path strips a ballot cast by anyone the viewer has blocked
        // OR who has blocked the viewer; if the winner resolution used the
        // narrower set, the count on screen and the recipe written into the
        // week would disagree — which is the BUT-1908 harm arriving through
        // the direction this ticket added.
        blocked = (await blockFilter.requireBlockedIds()).union(
          await blockFilter.requireBlockedByIds(),
        );
      } catch (e) {
        AppLogger.warning(
          'Refusing to close poll $messageId: block list unreadable ($e)',
        );
        // BUT-1922: the refusal is the same either way; only the advice
        // differs. Since that lookup is server-only, an offline device is now
        // the ordinary way to get here, and telling that user to try again
        // sends them at a button that cannot work yet.
        throw PollCloseRefusedException(
          isFirebaseOfflineError(e)
              ? PollCloseRefusal.blockListOffline
              : PollCloseRefusal.blockListUnknown,
        );
      }
      // Through the SAME helper the display path uses.
      final filtered = stripBlockedBallots(existing, blocked);
      final resolvablePoll = _extractPoll(filtered) ?? existingPoll;

      // READ everything the plan write needs, and keep the write itself for
      // after the close. Every refusal in here therefore happens while the
      // poll is still open (BUT-1925).
      //
      // Only creator-triggered closes resolve into a plan. A non-creator's
      // close writes NOTHING: the repository refuses when
      // `pollMap['creatorId'] != closerId`.
      PlanCommit? commitPlan;
      if (resolvablePoll.creatorId == currentUserId) {
        final winner = resolvablePoll.leader;
        if (winner?.recipeId != null) {
          final conversation = await _messagingRepository.getConversation(
            existing.conversationId,
          );
          final isGroup = conversation?.isGroup ?? false;

          if (isGroup && conversation != null) {
            commitPlan = await _prepareWinnerForGroupPlan(
              winnerRecipeId: winner!.recipeId!,
              conversation: conversation,
              creatorId: currentUserId,
              // The poll's creator is the dish's proposer: every option is
              // built in one `Poll.fromOptions(creatorId: ...)` call and
              // nothing adds an option later, so no per-option author field
              // exists or is needed. Read from the poll rather than from
              // `currentUserId` — they hold the same uid only because the gate
              // above resolves a winner for the creator alone.
              proposedBy: resolvablePoll.creatorId,
              votedInBy: winner.voterIds,
            );
          } else if (conversation != null) {
            commitPlan = await _prepareWinnerForWeeklyPlan(
              winnerRecipeId: winner!.recipeId!,
            );
          }
        }
      }

      // Close first. The transaction refuses a poll somebody else already
      // closed, and that refusal is what makes the plan write below happen at
      // most once — a caller whose pre-read said "open" still loses here.
      final closedByThisCall = await _messagingRepository.closePoll(
        messageId: messageId,
        closerId: currentUserId,
      );

      if (!closedByThisCall) {
        AppLogger.debug(
          'Poll $messageId was closed by someone else — writing no plan',
        );
        return;
      }

      // The one-way door is shut. A failure from here on leaves the poll
      // closed with no dish planned, which is the trade Malin took — so it
      // gets its own type rather than the sentence that says the close failed.
      // `commitPlan` is null for the paths that legitimately write nothing
      // (a non-creator's close, no winner, an unresolvable recipe, a service
      // the locator does not hold): those close and stop, as they always did.
      if (commitPlan != null) {
        try {
          await commitPlan();
        } catch (e) {
          AppLogger.error(
            'Poll $messageId closed but the winner never reached the plan',
            e,
          );
          throw PollClosedWithoutPlanException(e);
        }
      }
    } on PollCloseRefusedException {
      // BUT-1926: already logged, at the warning level the refusal deserves.
      // Re-logging it as an error made every deliberate guard look like a
      // crash in the log, twice over.
      rethrow;
    } on PollClosedWithoutPlanException {
      // Logged where it was raised, with the underlying cause. The generic
      // branch below would log "Failed to close poll", and the poll DID close.
      rethrow;
    } catch (e) {
      AppLogger.error('Failed to close poll $messageId', e);
      rethrow;
    }
  }

  /// Extract a `Poll` from a `Message.metadata.poll` map, or null if absent.
  Poll? _extractPoll(Message? message) {
    final metadata = message?.metadata;
    if (metadata == null) return null;
    final pollMap = metadata['poll'];
    if (pollMap is! Map) return null;
    try {
      return Poll.fromMap(Map<String, dynamic>.from(pollMap));
    } catch (e) {
      AppLogger.warning('Failed to parse poll from metadata: $e');
      return null;
    }
  }

  /// Find the winner recipe in the local recipe cache. Returns null if
  /// the recipe is not loaded (stale cache, deleted, etc.); callers treat
  /// that as a skip-auto-resolution signal.
  Recipe? _findWinnerRecipe(
    UnifiedRecipeService recipeService,
    String winnerRecipeId,
  ) {
    for (final r in recipeService.recipes) {
      if (r.id == winnerRecipeId) return r;
    }
    return null;
  }

  /// Today-anchored next empty middag slot. Walks today → Sunday; if the
  /// rest of the week is full, falls back to `(today, ovrigt)` (multi-slot).
  ({DayOfWeek day, MealSlot slot}) _nextAvailableMiddagSlot(
    DateTime anchor,
    bool Function(DayOfWeek day, MealSlot slot) isOccupied,
  ) {
    final anchorIndex = DayOfWeek.fromDateTime(anchor).index;
    for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
      final candidate = DayOfWeek.values[i];
      if (!isOccupied(candidate, MealSlot.middag)) {
        return (day: candidate, slot: MealSlot.middag);
      }
    }
    return (day: DayOfWeek.values[anchorIndex], slot: MealSlot.ovrigt);
  }

  /// Reads what the personal-plan append needs and returns the WRITE as a
  /// closure, or null when there is nothing to write.
  ///
  /// Split from the write (BUT-1925) so every refusal below happens while the
  /// poll is still open. The close is one-way, so a read that fails after it
  /// would cost the user their retry.
  Future<PlanCommit?> _prepareWinnerForWeeklyPlan({
    required String winnerRecipeId,
  }) async {
    final planService = _weeklyPlanService();
    final recipeService = _recipeService();
    if (planService == null || recipeService == null) {
      AppLogger.warning(
        'Auto-resolution skipped — required services not registered',
      );
      return null;
    }

    final winnerRecipe = _findWinnerRecipe(recipeService, winnerRecipeId);
    if (winnerRecipe == null) {
      AppLogger.warning(
        'Auto-resolution skipped — winner recipe $winnerRecipeId not found',
      );
      return null;
    }

    final now = clock.now();
    // BUT-1928. `getWeek` answers a failed read with an EMPTY plan, so the
    // save below would write a one-entry week built from nothing. On a week
    // that already exists the server refuses it (the empty plan's fresh
    // `createdAt`; W2 in `weekly-menu-plans-rules.test.ts`). Throwing leaves
    // the poll open, because this runs BEFORE the close (BUT-1925), which is
    // the recoverable failure; a silent skip would burn a one-way close.
    final read = await planService.readWeek(now);
    if (read.readFailed) {
      throw StateError(
        'Refusing to write the poll winner: the current week could not be read',
      );
    }
    final plan = read.plan;
    final target = _nextAvailableMiddagSlot(now, plan.isOccupied);

    final updatedPlan = planService.addEntry(
      plan: plan,
      day: target.day,
      slot: target.slot,
      recipe: winnerRecipe,
    );
    return () => planService.save(updatedPlan);
  }

  /// Group-plan auto-resolution path. Reads what the append needs and returns
  /// the WRITE as a closure, or null when there is nothing to write.
  ///
  /// The group plan lives at a deterministic doc ID (`{groupId}_{YYYY}-W{WW}`),
  /// so two closes race on ONE document; that makes the upsert idempotent, not
  /// the append. What keeps a second append from landing is the close itself,
  /// which is now a transaction and runs BETWEEN this read and that write
  /// (BUT-1925).
  Future<PlanCommit?> _prepareWinnerForGroupPlan({
    required String winnerRecipeId,
    required Conversation conversation,
    required String creatorId,
    required String proposedBy,
    required List<String> votedInBy,
  }) async {
    final groupService = _groupPlanService();
    final recipeService = _recipeService();
    if (groupService == null || recipeService == null) {
      AppLogger.warning(
        'Auto-resolution (group) skipped — required services not registered',
      );
      return null;
    }

    final winnerRecipe = _findWinnerRecipe(recipeService, winnerRecipeId);
    if (winnerRecipe == null) {
      AppLogger.warning(
        'Auto-resolution (group) skipped — winner recipe $winnerRecipeId not found',
      );
      return null;
    }

    final now = clock.now();

    // Fetch-or-build the group plan. First-time creation seeds every
    // conversation participant as an editor; the closer (creator) is
    // admin. Existing plans keep their membership intact.
    final initialParticipants = <GroupMenuParticipant>[
      for (final pid in conversation.participantIds)
        GroupMenuParticipant(
          userId: pid,
          permission: pid == creatorId
              ? SharedListPermission.admin
              : SharedListPermission.edit,
          addedAt: now,
        ),
    ];
    // Build-only (no persist). The single `save()` below persists the
    // plan WITH the winner entry already appended — saves one Firestore
    // write per new-group-week vs. create-then-save.
    //
    // BUT-1928, and the reason this is `readOrBuildWeek`: building on a FAILED
    // read produces a fresh empty plan whose id is the same deterministic
    // `{groupId}_{ISO week}`. Throwing here leaves the poll open for a retry,
    // because this whole method runs before the close (BUT-1925).
    final read = await groupService.readOrBuildWeek(
      groupId: conversation.id,
      creatorId: creatorId,
      date: now,
      initialParticipants: initialParticipants,
    );
    final GroupWeeklyMenuPlan? plan = read.plan;
    if (read.readFailed || plan == null) {
      throw StateError(
        'Refusing to write the poll winner: the group week could not be read',
      );
    }

    final target = _nextAvailableMiddagSlot(now, plan.isOccupied);

    final updatedPlan = groupService.addEntry(
      plan: plan,
      actorId: creatorId,
      day: target.day,
      slot: target.slot,
      recipe: winnerRecipe,
      proposedBy: proposedBy,
      votedInBy: votedInBy,
    );
    return () => groupService.save(plan: updatedPlan, actorId: creatorId);
  }
}
