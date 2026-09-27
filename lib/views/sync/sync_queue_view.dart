// lib/views/sync/sync_queue_view.dart
//
// P4-U19: "Väntar på synk", the user's view of the offline queue.
//
//   produktregler.md:190  "Mer → Väntar på synk: antal poster, vad de rör,
//                          ålder, och de permanenta felen först. Nås även
//                          från köindikatorn i toppfältet."
//   produktregler.md:189  permanent failures go to "Väntar på dig" with the
//                          cause in words, and each has an action.
//   produktregler.md:192  nothing leaves the queue without the server's
//                          confirmation or being shown here as a failure.
//   Skarmar v12 del 4 #synkko (light and dark): the drawing.
//   fas2/block288-uxfrysning.json TR::FLOW::08::kovy::vantar-pa-synk.
//
// The data is schema 3 (P5-U35) through SyncQueueSource.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/sync/sync_queue_row.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';

class SyncQueueView extends StatefulWidget {
  const SyncQueueView({this.backTo, super.key});

  /// The name of the view Back returns to, when it is known ("Tillbaka till
  /// Mer", #synkko; tillganglighetshandoff 'Navigation & toppfält').
  final String? backTo;

  static const Key syncNowKey = ValueKey<String>('sync-queue-sync-now');
  static const Key emptyKey = ValueKey<String>('sync-queue-empty');
  static const Key countKey = ValueKey<String>('sync-queue-count');

  @override
  State<SyncQueueView> createState() => _SyncQueueViewState();
}

class _SyncQueueViewState extends State<SyncQueueView> {
  late final SyncQueueSource _source = SyncQueueSource.resolve();
  StreamSubscription<QueueSnapshot>? _subscription;
  QueueSnapshot _queue = QueueSnapshot.empty;
  bool _syncing = false;

  /// The changes an action runs on, by kind and id (never by position).
  final Set<String> _busy = {};

  /// The changes the user chose to throw away, hidden from the list while
  /// their Ångra window is open, by kind and id.
  final Set<String> _discarding = {};

  @override
  void initState() {
    super.initState();
    _subscription = _source.watchChanges().listen(
      (queue) {
        if (mounted) setState(() => _queue = queue);
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static String _busyKey(QueuedChange c) => '${c.kind.name}:${c.id}';

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await _source.syncNow();
    } catch (e) {
      AppLogger.warning('SyncQueueView: sync now failed: $e');
      if (mounted) {
        final l10n = context.l10n;
        SnackBarUtils.showFailure(
          context,
          what: l10n.syncQueueSyncFailed,
          preserved: l10n.syncQueueChangesKept,
          action: FailureAction.retry(_syncNow),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _retry(QueuedChange change) async {
    final key = _busyKey(change);
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await _source.retry(change);
    } catch (e) {
      AppLogger.warning('SyncQueueView: retry failed: $e');
      if (mounted) {
        final l10n = context.l10n;
        SnackBarUtils.showFailure(
          context,
          what: l10n.syncQueueRetryFailed,
          preserved: l10n.syncQueueChangeKept,
          action: FailureAction.retry(() => _retry(change)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// "Släng ändringen" is class 1 (produktregler.md:132, "omedelbar + 7 s
  /// Ångra-snackbar"; :140 "Ångra finns där data försvinner"). The change
  /// leaves the list at once and is thrown away only when the Ångra window
  /// closes without Ångra; until then the queue is untouched.
  void _discard(QueuedChange change) {
    final key = _busyKey(change);
    if (_busy.contains(key) || !_discarding.add(key)) return;
    setState(() {});
    final source = _source;
    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.syncQueueDiscarded,
      onUndo: () {
        if (mounted) setState(() => _discarding.remove(key));
      },
      onCommit: () async {
        try {
          await source.discard(change);
          // The key stays hidden: the queue's next read no longer has it.
        } catch (e) {
          AppLogger.warning('SyncQueueView: discard failed: $e');
          if (!mounted) return;
          setState(() => _discarding.remove(key));
          final l10n = context.l10n;
          SnackBarUtils.showFailure(
            context,
            what: l10n.syncQueueDiscardFailed,
            preserved: l10n.syncQueueChangeKept,
          );
        }
      },
    );
  }

  /// The queue without the changes whose Ångra window is open.
  QueueSnapshot get _visibleQueue {
    if (_discarding.isEmpty) return _queue;
    return QueueSnapshot(
      [
        ..._queue.needsUser,
        ..._queue.draining,
      ].where((c) => !_discarding.contains(_busyKey(c))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final queue = _visibleQueue;
    final side = ButleryTopBar.sideMargin(context);

    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: l10n.syncQueueTitle,
        backTo: widget.backTo,
        // The count as drawn, read as words (#synkko: "7").
        trailing: queue.isEmpty
            ? null
            : Semantics(
                label: l10n.offlineBannerPending(queue.total),
                excludeSemantics: true,
                child: Text(
                  '${queue.total}',
                  key: SyncQueueView.countKey,
                  style: AppTextStyles.captionBase.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The offline line as a status: here it has nowhere to lead.
            StatusIndicators.offlineIndicator(),
            Expanded(
              child: queue.isEmpty
                  ? _Empty(side: side)
                  : ListView(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        side,
                        AppDimensions.spacingMd,
                        side,
                        AppDimensions.spacingMd,
                      ),
                      children: [
                        if (queue.needsUser.isNotEmpty) ...[
                          _SectionHeading(
                            icon: Icons.error_outline,
                            text: l10n.syncQueueNeedsYouHeader(
                              queue.needsUser.length,
                            ),
                            // text.danger, as drawn (#synkko).
                            color: cs.error,
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            l10n.syncQueueNeedsYouHint,
                            style: AppTextStyles.captionBase.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          for (final change in queue.needsUser)
                            SyncQueueNeedsYouCard(
                              key: ValueKey(
                                'sync-card-${change.kind.name}-${change.id}',
                              ),
                              change: change,
                              busy: _busy.contains(_busyKey(change)),
                              onRetry: () => _retry(change),
                              onDiscard: () => _discard(change),
                            ),
                          const SizedBox(height: AppDimensions.spacingL),
                        ],
                        if (queue.draining.isNotEmpty) ...[
                          if (queue.needsUser.isNotEmpty)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: cs.outlineVariant,
                            ),
                          const SizedBox(height: AppDimensions.spacingMd - 2),
                          _SectionHeading(
                            icon: Icons.schedule,
                            text: l10n.syncQueueQueuedHeader(
                              queue.draining.length,
                            ),
                            color: cs.onSurfaceVariant,
                          ),
                          for (final change in queue.draining)
                            SyncQueueRow(change: change),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            l10n.syncQueueOrderNote,
                            style: AppTextStyles.captionBase.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (!queue.isEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    side,
                    AppDimensions.spacingSm + AppDimensions.spacingXs,
                    side,
                    AppDimensions.spacingMd,
                  ),
                  child: OutlinedButton.icon(
                    key: SyncQueueView.syncNowKey,
                    // Offline the queue cannot be sent; the banner above says
                    // why.
                    onPressed: _syncing || !_source.isOnline ? null : _syncNow,
                    icon: const Icon(Icons.sync),
                    label: Text(
                      _syncing ? l10n.syncQueueSyncing : l10n.syncQueueSyncNow,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Väntar på dig · 2" / "I kö · 5": a small icon and an uppercase heading.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppDimensions.iconSizeS, color: color),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppTextStyles.captionBase.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing waits. Not drawn; the view says so in one sentence
/// (interpretation).
class _Empty extends StatelessWidget {
  const _Empty({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppDimensions.spacingL,
        side,
        AppDimensions.spacingL,
      ),
      child: Text(
        context.l10n.syncQueueEmpty,
        key: SyncQueueView.emptyKey,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
