/// Resume-onboarding persistence + 24h-no-progress nudge (BUT-675).
///
/// Writes `users/{uid}/onboarding/progress` on each step transition so a user
/// who closes the app mid-flow can resume at the next incomplete step on
/// re-launch instead of being routed home with a half-finished profile.
///
/// Why a separate doc (not a field on the user profile): keeps the user
/// document hot-cache lean (it's read on every app open) and lets us evolve
/// the progress schema without bumping the user-profile model. Also lines up
/// with the GDPR-flagged `consent` and `acquisition` sub-paths that follow
/// the same owner-only access pattern.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';

/// Canonical step identifiers for onboarding progress. Order matters: the
/// next-incomplete-step resolver advances in this exact sequence.
///
/// `pageIndex` is the single source of truth for the wizard's PageView order.
/// Both `OnboardingViewModel` and the resume resolver read from this field
/// instead of mirroring the table — keeps the two in sync if a page is
/// inserted, removed, or reordered.
enum OnboardingStep {
  ageGate('age_gate', 0),
  welcome('welcome', 1),
  allergens('allergens', 2),
  dietary('dietary', 3),
  firstRecipe('first_recipe', 4)
  ;

  final String wireName;
  final int pageIndex;
  const OnboardingStep(this.wireName, this.pageIndex);

  static OnboardingStep? fromWireName(String? name) {
    if (name == null) return null;
    for (final step in OnboardingStep.values) {
      if (step.wireName == name) return step;
    }
    return null;
  }

  static OnboardingStep? fromPageIndex(int index) {
    for (final step in OnboardingStep.values) {
      if (step.pageIndex == index) return step;
    }
    return null;
  }
}

/// Snapshot of stored onboarding-progress state.
class OnboardingProgress {
  final OnboardingStep? lastCompletedStep;
  final DateTime? completedAt;
  final bool completed;

  const OnboardingProgress({
    this.lastCompletedStep,
    this.completedAt,
    this.completed = false,
  });

  bool get hasProgress => lastCompletedStep != null;

  /// True when the most recent step write is older than [threshold].
  /// Returns false when no progress has been recorded yet — there's nothing
  /// to nudge about until the user has at least committed one step.
  bool isStale(DateTime now, Duration threshold) {
    if (completed) return false;
    if (completedAt == null) return false;
    return now.difference(completedAt!) >= threshold;
  }
}

/// Routes the user to the next incomplete step. Caller maps the step to a
/// concrete page index in `OnboardingViewModel`.
class OnboardingProgressService {
  final FirebaseFirestore _firestore;
  final AnalyticsService? _analytics;

  /// Threshold after which we consider an in-progress onboarding "abandoned"
  /// and surface the resume-nudge. Spec: 24 hours.
  static const Duration abandonThreshold = Duration(hours: 24);

  OnboardingProgressService({
    required FirebaseFirestore firestore,
    AnalyticsService? analytics,
  }) : _firestore = firestore,
       _analytics = analytics;

  DocumentReference<Map<String, dynamic>> _progressDoc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('onboarding')
        .doc('progress');
  }

  /// Reads the current onboarding-progress snapshot. Returns an empty
  /// snapshot (`hasProgress == false`) if no document exists yet — never
  /// throws on missing-doc, since first-time users hit this path on launch.
  Future<OnboardingProgress> readProgress(String userId) async {
    try {
      final snap = await _progressDoc(userId).get();
      if (!snap.exists) return const OnboardingProgress();
      final data = snap.data() ?? const <String, dynamic>{};
      final step = OnboardingStep.fromWireName(data['step'] as String?);
      DateTime? completedAt;
      final ts = data['completedAt'];
      if (ts is Timestamp) {
        completedAt = ts.toDate();
      } else if (ts is DateTime) {
        // Some test fakes hand back DateTime directly when serverTimestamp()
        // is resolved client-side.
        completedAt = ts;
      }
      final completed = data['completed'] == true;
      return OnboardingProgress(
        lastCompletedStep: step,
        completedAt: completedAt,
        completed: completed,
      );
    } catch (e) {
      AppLogger.warning('OnboardingProgressService.readProgress failed: $e');
      return const OnboardingProgress();
    }
  }

  /// Records that [step] just finished. The final-step write atomically
  /// flips `completed: true` so the resume check on next launch routes home.
  Future<void> markStepComplete({
    required String userId,
    required OnboardingStep step,
    required bool isFinalStep,
  }) async {
    try {
      // Client-side timestamp by design: the resume/abandon logic only ever
      // compares this to the user's own `DateTime.now()` at next launch, so
      // wall-clock from the same device is sufficient. Avoids the
      // `FieldValue.serverTimestamp()` / FakeFirebaseFirestore platform-
      // binding clash documented in `firebase_user_repository_test.dart`.
      await _progressDoc(userId).set({
        'step': step.wireName,
        'completedAt': Timestamp.now(),
        'completed': isFinalStep,
      }, SetOptions(merge: true));
    } catch (e) {
      // Resume-state is best-effort; never block onboarding on a write failure.
      AppLogger.warning(
        'OnboardingProgressService.markStepComplete failed: $e',
      );
    }
  }

  /// Resolves the page index the user should resume at, given their last
  /// completed step. Returns null when onboarding is done — caller routes home.
  int? resolveResumePageIndex(OnboardingProgress progress) {
    if (progress.completed) return null;
    final last = progress.lastCompletedStep;
    if (last == null) return 0; // never started — start at first step
    if (last == OnboardingStep.firstRecipe) {
      // Final step recorded but `completed` flag missing — treat as resume
      // at last page so the user can complete the wizard cleanly.
      return last.pageIndex;
    }
    return last.pageIndex + 1;
  }

  /// Emits `onboarding_resumed`. Caller invokes when re-entering mid-flow
  /// (i.e. resolveResumePageIndex returned a non-zero index).
  Future<void> logResumed({required OnboardingStep? lastStep}) async {
    await _analytics?.logEvent(
      name: AnalyticsEvents.onboardingResumed,
      parameters: {
        'last_step': lastStep?.wireName ?? 'none',
      },
    );
  }

  /// Emits `onboarding_abandoned`. Caller invokes when the 24h-stale nudge
  /// is shown so we can measure how often users actually drop out.
  Future<void> logAbandoned({required OnboardingStep? lastStep}) async {
    await _analytics?.logEvent(
      name: AnalyticsEvents.onboardingAbandoned,
      parameters: {
        'last_step': lastStep?.wireName ?? 'none',
      },
    );
  }

  /// Convenience: should the resume nudge be shown right now? Pure logic —
  /// `now` is injected for fakeAsync tests.
  bool shouldShowAbandonedNudge(OnboardingProgress progress, DateTime now) {
    return progress.hasProgress && progress.isStale(now, abandonThreshold);
  }
}
