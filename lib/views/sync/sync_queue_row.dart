// lib/views/sync/sync_queue_row.dart
//
// P4-U19: one waiting change in "Väntar på synk", drawn in Skarmar v12 del 4
// #synkko. A permanent failure is a card with its cause in words and its
// actions (produktregler.md:188); a queued change is a row with what it
// concerns and its age (produktregler.md:190).
//
// P6-U08b: a queued change that failed says when it is sent again ("nästa
// försök om 8 s", #synkko), and a failure gets the actions produktregler.md
// :188 and the drawing name: Försök igen or Försök mindre, Spara som kopia,
// Släng ändringen.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline/unsent_image_expiry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// What [change] concerns, in words ("vad de rör", produktregler.md:190).
String describeQueuedChange(AppLocalizations l10n, QueuedChange change) {
  final subject = change.subject;
  if (change.isCommentGroup) {
    return subject == null
        ? l10n.syncQueueCommentUnnamed
        : l10n.syncQueueComment(subject);
  }
  if (change.isImageGroup) return l10n.syncQueueCookSnap(change.photoCount);
  if (change.isChatImage) return l10n.syncQueueChatImage;
  if (change.kind == QueuedChangeKind.image) {
    return subject == null
        ? l10n.syncQueueImage
        : l10n.syncQueueImageFor(subject);
  }
  final title = subject ?? l10n.syncQueueUnnamedRecipe;
  return switch (change.operation) {
    QueuedOperation.create => l10n.syncQueueRecipeCreated(title),
    QueuedOperation.delete => l10n.syncQueueRecipeDeleted(title),
    QueuedOperation.tag => l10n.syncQueueRecipeTagged(title),
    QueuedOperation.update ||
    QueuedOperation.upload => l10n.syncQueueRecipeUpdated(title),
  };
}

/// Why [change] waits for the user, in the words produktregler.md:188 names.
String describeQueuedReason(AppLocalizations l10n, QueuedChange change) =>
    change.isCommentGroup
    ? l10n.syncQueueReasonCommentFailed
    : change.isChatImage
    ? l10n.syncQueueReasonChatImageFailed
    : switch (change.reason) {
        QueuedChangeReason.notFound => l10n.syncQueueReasonNotFound,
        QueuedChangeReason.permissionDenied => l10n.syncQueueReasonPermission,
        QueuedChangeReason.tooLarge => l10n.syncQueueReasonTooLarge,
        QueuedChangeReason.dependencyFailed => l10n.syncQueueReasonDependency,
        QueuedChangeReason.retriesExhausted => l10n.syncQueueReasonExpired,
        QueuedChangeReason.unknown => l10n.syncQueueReasonUnknown,
      };

/// When [change] is sent again after a failed attempt, as #synkko writes it
/// ("nästa försök om 8 s"), or null when no retry time lies ahead. Rounded
/// up, so the line never says 0 s while the wait is still on; a minute or
/// more is written in minutes (content-style-guide.md:31).
String? describeNextAttempt(AppLocalizations l10n, QueuedChange change) {
  final next = change.nextAttemptAt;
  if (next == null) return null;
  final left = next.difference(clock.now());
  if (left <= Duration.zero) return null;
  final seconds = (left.inMilliseconds / 1000).ceil();
  if (seconds < 60) return l10n.syncQueueNextAttemptSeconds(seconds);
  return l10n.syncQueueNextAttemptMinutes((seconds / 60).ceil());
}

/// How long until an unsent photo is thrown away by itself, or null for a
/// change that is not one. The notice comes before the removal, so the user
/// can retry or keep a copy first.
String? describeAutoDiscard(AppLocalizations l10n, QueuedChange change) {
  final since = change.unsentSince;
  if (change.kind != QueuedChangeKind.image || !change.needsUser) return null;
  if (since == null) return null;
  return l10n.syncQueueAutoDiscard(unsentImageDaysLeft(since, clock.now()));
}

/// How long [change] has waited ("ålder", produktregler.md:190), written as
/// content-style-guide.md:31-35 writes durations: "nu", "9 min",
/// "1 h 30 min".
String describeQueuedAge(AppLocalizations l10n, QueuedChange change) {
  var age = clock.now().difference(change.queuedAt);
  if (age.isNegative) age = Duration.zero;
  if (age.inMinutes < 1) return l10n.syncQueueAgeNow;
  if (age.inHours < 1) return l10n.syncQueueAgeMinutes(age.inMinutes);
  if (age.inDays < 1) {
    final minutes = age.inMinutes % 60;
    return minutes == 0
        ? l10n.syncQueueAgeHours(age.inHours)
        : l10n.syncQueueAgeHoursMinutes(age.inHours, minutes);
  }
  return l10n.syncQueueAgeDays(age.inDays);
}

/// A permanent failure (#synkko "Väntar på dig"): a card edged in
/// text.danger with the cause in text.danger and its actions.
///
/// The actions (produktregler.md:188 "Försök igen · Spara som kopia ·
/// Släng"; #synkko draws "Försök mindre" for a too-large image):
/// * the first is "Försök mindre" for a too-large image
///   ([QueuedChange.canTrySmaller]), else "Försök igen";
/// * "Spara som kopia" for a recipe write ([QueuedChange.canSaveAsCopy]);
/// * "Släng ändringen" on every failure ([QueuedChange.canDiscard]); on a new
///   recipe that exists only on this phone it asks first (Q6-11 = B,
///   [QueuedChange.discardAsksFirst]).
///
/// Interpretation: the non-destructive actions are outlined buttons
/// (ram-kontroll-a / text-kontroll-a in #synkko), and Släng is text in
/// text-kontroll-b, which is text.danger (#9C3B23 light, #DE9078 dark).
///
/// text.danger is colorScheme.error: #9C3B23 light, #DE9078 dark, the drawn
/// ram-behallare-d and text-innehall-f (tokens.json semantic).
class SyncQueueNeedsYouCard extends StatelessWidget {
  const SyncQueueNeedsYouCard({
    required this.change,
    required this.onRetry,
    required this.onDiscard,
    this.onSaveAsCopy,
    this.onTrySmaller,
    this.busy = false,
    super.key,
  });

  final QueuedChange change;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// "Spara som kopia"; shown when [QueuedChange.canSaveAsCopy] and set.
  final VoidCallback? onSaveAsCopy;

  /// "Försök mindre"; shown in place of Försök igen when
  /// [QueuedChange.canTrySmaller] and set.
  final VoidCallback? onTrySmaller;

  /// While an action on this change runs, the actions show the plate line and
  /// ignore taps.
  final bool busy;

  static Key retryKey(QueuedChange c) =>
      ValueKey('sync-retry-${c.kind.name}-${c.id}');
  static Key discardKey(QueuedChange c) =>
      ValueKey('sync-discard-${c.kind.name}-${c.id}');
  static Key copyKey(QueuedChange c) =>
      ValueKey('sync-copy-${c.kind.name}-${c.id}');
  static Key smallerKey(QueuedChange c) =>
      ValueKey('sync-smaller-${c.kind.name}-${c.id}');

  static const double _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final what = describeQueuedChange(l10n, change);
    final autoDiscard = describeAutoDiscard(l10n, change);
    final trySmaller = change.canTrySmaller ? onTrySmaller : null;
    final saveAsCopy = change.canSaveAsCopy ? onSaveAsCopy : null;
    return ButleryOutlinedBox(
      margin: const EdgeInsets.only(top: AppDimensions.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space12,
      ),
      borderColor: cs.error,
      borderWidth: _edge,
      radius: AppDimensions.radiusControl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            what,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            describeQueuedReason(l10n, change),
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.error,
            ),
          ),
          if (autoDiscard != null) ...[
            const SizedBox(height: AppDimensions.space4),
            Text(
              autoDiscard,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space8),
          Wrap(
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space4,
            children: [
              if (trySmaller != null)
                _action(
                  context,
                  key: smallerKey(change),
                  label: l10n.syncQueueTrySmaller,
                  a11y: l10n.syncQueueTrySmallerA11y(what),
                  onPressed: trySmaller,
                )
              else
                _action(
                  context,
                  key: retryKey(change),
                  label: l10n.syncQueueRetry,
                  a11y: l10n.syncQueueRetryA11y(what),
                  onPressed: onRetry,
                ),
              if (saveAsCopy != null)
                _action(
                  context,
                  key: copyKey(change),
                  label: l10n.syncQueueSaveAsCopy,
                  a11y: l10n.syncQueueSaveAsCopyA11y(what),
                  onPressed: saveAsCopy,
                ),
              if (change.canDiscard)
                Semantics(
                  label: l10n.syncQueueDiscardA11y(what),
                  excludeSemantics: true,
                  button: true,
                  child: ButleryTextButton(
                    key: discardKey(change),
                    tone: ButleryTextButtonTone.danger,
                    label: l10n.syncQueueDiscard,
                    onPressed: busy ? null : onDiscard,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required String label,
    required String a11y,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      label: a11y,
      excludeSemantics: true,
      button: true,
      // Busy keeps the name and gets the plate line; a second tap is ignored
      // rather than the button going disabled (Komponentark v1:365).
      child: ActionButtons.outlinedButton(
        context,
        key: key,
        label: label,
        isLoading: busy,
        onPressed: onPressed,
      ),
    );
  }
}

/// A change the queue sends by itself (#synkko "I kö"): what it concerns,
/// a second line when it waits on an earlier change, and its age.
class SyncQueueRow extends StatelessWidget {
  const SyncQueueRow({required this.change, super.key});

  final QueuedChange change;

  static Key rowKey(QueuedChange c) =>
      ValueKey('sync-row-${c.kind.name}-${c.id}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // text.secondary (#5B6959 light, #A9B2A0 dark; tokens.json semantic).
    // Interpretation: #synkko's raw slot --r04slot-620 is #627061 light but
    // #C9D3C4 (text.bodyMuted) dark (Skarmar v12 del 4:64); no token pairs
    // those two, so the token text.secondary decides the dark value.
    final secondary = AppTextStyles.captionBase.copyWith(
      color: cs.onSurfaceVariant,
    );
    // Shown offline too: #synkko draws "nästa försök om 8 s" under the
    // offline banner (Skarmar v12 del 4:245, :271, :275).
    final next = describeNextAttempt(l10n, change);
    return Container(
      key: rowKey(change),
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.space8,
      ),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    describeQueuedChange(l10n, change),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  if (change.waitsOnEarlier)
                    Text(l10n.syncQueueWaitsOnEarlier, style: secondary)
                  else if (next != null)
                    Text(next, style: secondary),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(
              describeQueuedAge(l10n, change),
              style: secondary.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
