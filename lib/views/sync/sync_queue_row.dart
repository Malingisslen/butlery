// lib/views/sync/sync_queue_row.dart
//
// P4-U19: one waiting change in "Väntar på synk", drawn in Skarmar v12 del 4
// #synkko. A permanent failure is a card with its cause in words and its
// actions (produktregler.md:189); a queued change is a row with what it
// concerns and its age (produktregler.md:190).
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// What [change] concerns, in words ("vad de rör", produktregler.md:190).
String describeQueuedChange(AppLocalizations l10n, QueuedChange change) {
  final subject = change.subject;
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

/// Why [change] waits for the user, in the words produktregler.md:189 names.
String describeQueuedReason(AppLocalizations l10n, QueuedChange change) =>
    switch (change.reason) {
      QueuedChangeReason.notFound => l10n.syncQueueReasonNotFound,
      QueuedChangeReason.permissionDenied => l10n.syncQueueReasonPermission,
      QueuedChangeReason.tooLarge => l10n.syncQueueReasonTooLarge,
      QueuedChangeReason.dependencyFailed => l10n.syncQueueReasonDependency,
      QueuedChangeReason.unknown => l10n.syncQueueReasonUnknown,
    };

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
/// text.danger with the cause in text.danger and two actions.
///
/// text.danger is colorScheme.error: #9C3B23 light, #DE9078 dark, the drawn
/// ram-behallare-d and text-innehall-f (tokens.json semantic).
class SyncQueueNeedsYouCard extends StatelessWidget {
  const SyncQueueNeedsYouCard({
    required this.change,
    required this.onRetry,
    required this.onDiscard,
    this.busy = false,
    super.key,
  });

  final QueuedChange change;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// While an action on this change runs, both are off.
  final bool busy;

  static Key retryKey(QueuedChange c) =>
      ValueKey('sync-retry-${c.kind.name}-${c.id}');
  static Key discardKey(QueuedChange c) =>
      ValueKey('sync-discard-${c.kind.name}-${c.id}');

  static const double _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final what = describeQueuedChange(l10n, change);
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spacingSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd - 3,
        vertical: AppDimensions.spacingMd - 5,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.error, width: _edge),
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            what,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            describeQueuedReason(l10n, change),
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Wrap(
            spacing: AppDimensions.spacingSm,
            runSpacing: AppDimensions.spacingXs,
            children: [
              // Interpretation: every failure offers "Försök igen". #synkko
              // (Skarmar v12 del 4 :257-259) draws "Försök mindre" on a
              // too-large image; sending a smaller copy is not built
              // (P6-U08b), and "Spara som kopia" (produktregler.md:188) is
              // not offered yet either.
              Semantics(
                label: l10n.syncQueueRetryA11y(what),
                excludeSemantics: true,
                button: true,
                child: OutlinedButton(
                  key: retryKey(change),
                  onPressed: busy ? null : onRetry,
                  child: Text(l10n.syncQueueRetry),
                ),
              ),
              Semantics(
                label: l10n.syncQueueDiscardA11y(what),
                excludeSemantics: true,
                button: true,
                child: TextButton(
                  key: discardKey(change),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  onPressed: busy ? null : onDiscard,
                  child: Text(l10n.syncQueueDiscard),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A change the queue sends by itself (#synkko "I kö"): what it concerns,
/// a second line when it waits on an earlier change, and its age. 56 dp tall
/// with a border.subtle line under it.
class SyncQueueRow extends StatelessWidget {
  const SyncQueueRow({required this.change, super.key});

  final QueuedChange change;

  static Key rowKey(QueuedChange c) =>
      ValueKey('sync-row-${c.kind.name}-${c.id}');

  static const double _minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // text.secondary (#627061 light, #93A48D dark; tokens.json semantic).
    final secondary = AppTextStyles.captionBase.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Container(
      key: rowKey(change),
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
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
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  if (change.waitsOnEarlier)
                    Text(l10n.syncQueueWaitsOnEarlier, style: secondary),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
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
