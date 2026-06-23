import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/admin/metric_tab_view.dart';
import 'package:butlery/views/admin/ops_log_view.dart';
import 'package:butlery/views/admin/parsing_details_view.dart';
import 'package:butlery/views/admin/widgets/anomaly_banner.dart';
import 'package:butlery/views/admin/admin_url_state_stub.dart'
    if (dart.library.js_interop) 'package:butlery/views/admin/admin_url_state_web.dart';

/// Top-level admin shell: a NavigationRail switching between the admin tools.
/// Reached only after the admin gate in `admin_main.dart`.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late int _index = _initialIndex();

  /// Initial tab from the URL (`?tab=<index>`), clamped to a valid tab.
  int _initialIndex() {
    final raw = Uri.base.queryParameters['tab'];
    final parsed = raw == null ? null : int.tryParse(raw);
    if (parsed == null) return 0;
    return parsed.clamp(0, _pages.length - 1);
  }

  void _selectTab(int index) {
    setState(() => _index = index);
    writeTabParam(index);
  }

  // Not const: the registry-driven tabs (MetricTabView) carry a closure for
  // their localized title, so the list is built per render. Migrating tabs are
  // swapped to MetricTabView one at a time (Phase 1).
  List<Widget> get _pages => [
    const FeedbackInboxView(),
    MetricTabView(
      title: (l) => l.adminImportTitle,
      keys: const [
        MetricKey.importDomains,
        MetricKey.importSuccess,
        MetricKey.importFailure,
        MetricKey.importSuccessRate,
        MetricKey.importDomainTable,
      ],
    ),
    MetricTabView(
      title: (l) => l.adminEngagementTitle,
      keys: const [
        MetricKey.engagementUsers,
        MetricKey.engagementActiveToday,
        MetricKey.engagementActive7d,
        MetricKey.engagementActive28d,
        MetricKey.engagementDailyTable,
      ],
    ),
    const ParsingDetailsView(),
    MetricTabView(
      title: (l) => l.adminRecipesTitle,
      keys: const [MetricKey.recipeTotal, MetricKey.recipeByMethod],
    ),
    const OpsLogView(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          const AnomalyBanner(),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.feedback_outlined),
                      selectedIcon: const Icon(Icons.feedback),
                      label: Text(l10n.adminNavFeedback),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.cloud_download_outlined),
                      selectedIcon: const Icon(Icons.cloud_download),
                      label: Text(l10n.adminNavImport),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.people_outline),
                      selectedIcon: const Icon(Icons.people),
                      label: Text(l10n.adminNavEngagement),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.rule_outlined),
                      selectedIcon: const Icon(Icons.rule),
                      label: Text(l10n.adminNavParsing),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: const Icon(Icons.restaurant_menu),
                      label: Text(l10n.adminNavRecipes),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.dns_outlined),
                      selectedIcon: const Icon(Icons.dns),
                      label: Text(l10n.adminNavOps),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pages[_index]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
