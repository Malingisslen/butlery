import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/metrics/metric_descriptor.dart';
import 'package:butlery/models/admin/parse_event.dart';
import 'package:butlery/repositories/parse_events_repository.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Opens the drill-down for a tapped metric row. Dispatches by [kind]; the only
/// kind today maps an import-domain row to its underlying parse events.
void handleMetricDrilldown(
  BuildContext context,
  MetricDrilldownKind kind,
  String rowLabel,
) {
  switch (kind) {
    case MetricDrilldownKind.parseEventsByDomain:
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _ParseEventsSheet(domain: rowLabel),
      );
  }
}

class _ParseEventsSheet extends StatefulWidget {
  final String domain;
  const _ParseEventsSheet({required this.domain});

  @override
  State<_ParseEventsSheet> createState() => _ParseEventsSheetState();
}

class _ParseEventsSheetState extends State<_ParseEventsSheet> {
  late final Future<ParseEventsPage> _future;

  @override
  void initState() {
    super.initState();
    _future = ServiceLocator.get<ParseEventsRepository>().getByDomain(
      widget.domain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        child: FutureBuilder<ParseEventsPage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: LoadingIndicator());
            }
            final page = snapshot.data ?? ParseEventsPage.empty;
            return ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingS,
                  ),
                  child: Text(
                    l10n.adminDrillImportTitle(widget.domain),
                    style: AppTextStyles.headlineBold,
                  ),
                ),
                if (page.events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    child: Text(
                      l10n.adminDrillEmpty,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.outline,
                      ),
                    ),
                  )
                else ...[
                  if (page.truncated)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacingSm,
                      ),
                      child: Text(
                        l10n.adminDrillTruncated(page.events.length),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final event in page.events) _EventTile(event: event),
                ],
                const SizedBox(height: AppDimensions.paddingL),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final ParseEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final ok = event.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? cs.primary : cs.error,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ok ? l10n.adminDrillSuccess : l10n.adminDrillFailure}'
                  ' · ${_formatTime(event.timestamp)}',
                  style: AppTextStyles.bodyMedium,
                ),
                if (event.url != null)
                  Text(
                    event.url!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? d) {
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
