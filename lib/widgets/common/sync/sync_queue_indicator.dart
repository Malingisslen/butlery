// lib/widgets/common/sync/sync_queue_indicator.dart
//
// P4-U19: the queue indicator in the top bar. "Köindikator i toppfältet när
// något väntar" (flows-roles-budget.md:111), and the queue view "Nås även från
// köindikatorn i toppfältet" (produktregler.md:190).
//
// PQ-04 = B (fas2/produktbeslut-2026-09-23.json): nothing while the queue
// drains by itself, and a saffron counter only when something needs the user
// (a permanent failure). Offline, the banner carries the waiting count
// (status_indicators.dart), so the bar adds nothing then either.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Rebuilds with the user's queue counts, live. Starts at
/// [QueueCounts.empty], so nothing shows before the first read.
class QueueCountsBuilder extends StatefulWidget {
  const QueueCountsBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, QueueCounts counts) builder;

  @override
  State<QueueCountsBuilder> createState() => _QueueCountsBuilderState();
}

class _QueueCountsBuilderState extends State<QueueCountsBuilder> {
  StreamSubscription<QueueCounts>? _subscription;
  QueueCounts _counts = QueueCounts.empty;

  @override
  void initState() {
    super.initState();
    _subscription = SyncQueueSource.resolve().watchCounts().listen(
      (counts) {
        if (mounted && counts != _counts) setState(() => _counts = counts);
      },
      // A count that cannot be read shows nothing rather than a guess.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _counts);
}

/// The saffron count, as the Mer rows draw it (Skarmar v12 del 2 #mer):
/// action.primary (colorScheme.secondary, #CE7C1E in both modes) behind
/// text.onActionPrimary (colorScheme.onSecondary, #17251D in both modes),
/// 10.5/700.
class SaffronCount extends StatelessWidget {
  const SaffronCount({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm - 1,
          vertical: AppDimensions.spacingXxs,
        ),
        child: Text(
          '$count',
          style: AppTextStyles.overline.copyWith(
            color: cs.onSecondary,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// The top bar's queue counter: a sync glyph with the saffron count, shown
/// only while [count] > 0. Tapping it opens "Väntar på synk".
class SyncQueueIndicator extends StatelessWidget {
  const SyncQueueIndicator({required this.count, super.key});

  /// Changes that wait for the user.
  final int count;

  static const Key buttonKey = ValueKey<String>('sync-queue-indicator');

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.syncQueueIndicatorA11y(count);
    return Semantics(
      container: true,
      button: true,
      identifier: 'sync-queue-indicator',
      label: label,
      excludeSemantics: true,
      child: IconButton(
        key: buttonKey,
        tooltip: label,
        onPressed: () => Navigator.of(context).pushNamed(Routes.syncQueue),
        icon: Badge(
          // The badge vocabulary of the rail (Skarmar v12 etapp 10
          // #bredskal): saffron with the count in ink.
          backgroundColor: Theme.of(context).colorScheme.secondary,
          textColor: Theme.of(context).colorScheme.onSecondary,
          label: Text(
            '$count',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          child: const Icon(Icons.sync_problem_outlined),
        ),
      ),
    );
  }
}

/// A root bar's actions with the queue counter in front when something
/// needs the user. With nothing to show and no [children] it takes no room,
/// so a bar without a counter is laid out exactly as before.
class QueueAwareActions extends StatelessWidget {
  const QueueAwareActions({
    required this.children,
    required this.gap,
    required this.wrap,
    this.rowKey,
    super.key,
  });

  /// The bar's own actions, already wrapped.
  final List<Widget> children;

  /// The space between the title and the actions, and between actions.
  final double gap;

  /// Wraps one action in the bar's hitbox.
  final Widget Function(Widget action) wrap;

  /// The key the bar gives its actions row.
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    return QueueCountsBuilder(
      builder: (context, counts) {
        final all = [
          if (counts.needsUser > 0)
            wrap(SyncQueueIndicator(count: counts.needsUser)),
          ...children,
        ];
        if (all.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsetsDirectional.only(start: gap),
          child: Row(
            key: rowKey,
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: all,
          ),
        );
      },
    );
  }
}
