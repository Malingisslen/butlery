import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
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
    return Scaffold(
      body: Column(
        children: [
          const AnomalyBanner(),
          Expanded(
            child: Row(
              children: [
                AdminRail(selectedIndex: _index, onSelected: _selectTab),
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

/// The admin shell's six tabs (produktregler.md:626): feedback, import,
/// engagement, parsing, recipes and ops.
///
/// Each tab carries the canonical focus ring around a 48 dp box and no focus
/// tint (Grafisk manual v6:209, :381; fas2/block288-uxfrysning.json
/// CSR::ROLE::tab::FOCUSED). The rail builds its own InkResponse around the
/// icon, so the ring follows that ancestor's focus node
/// (ButleryAncestorFocusRing), as a TabBar tab does.
class AdminRail extends StatelessWidget {
  const AdminRail({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static NavigationRailDestination _destination(
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    return NavigationRailDestination(
      icon: ButleryAncestorFocusRing(
        child: ButleryControlFocus.box(child: Icon(icon)),
      ),
      selectedIcon: ButleryAncestorFocusRing(
        child: ButleryControlFocus.box(child: Icon(selectedIcon)),
      ),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: ButleryControlFocus.themeWithoutFocusTint(Theme.of(context)),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        destinations: [
          _destination(
            Icons.feedback_outlined,
            Icons.feedback,
            l10n.adminNavFeedback,
          ),
          _destination(
            Icons.cloud_download_outlined,
            Icons.cloud_download,
            l10n.adminNavImport,
          ),
          _destination(
            Icons.people_outline,
            Icons.people,
            l10n.adminNavEngagement,
          ),
          _destination(Icons.rule_outlined, Icons.rule, l10n.adminNavParsing),
          _destination(
            Icons.restaurant_menu_outlined,
            Icons.restaurant_menu,
            l10n.adminNavRecipes,
          ),
          _destination(Icons.dns_outlined, Icons.dns, l10n.adminNavOps),
        ],
      ),
    );
  }
}
