import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/admin/metric_tab_view.dart';
import 'package:butlery/views/admin/ops_log_view.dart';
import 'package:butlery/views/admin/parsing_details_view.dart';
import 'package:butlery/views/admin/signup_allowlist_view.dart';
import 'package:butlery/views/admin/widgets/admin_top_bar.dart';
import 'package:butlery/views/admin/widgets/anomaly_banner.dart';
import 'package:butlery/views/admin/admin_url_state_stub.dart'
    if (dart.library.js_interop) 'package:butlery/views/admin/admin_url_state_web.dart';

/// Top-level admin shell: one dark bar with the admin tools as tabs, and the
/// chosen tool under it. Reached only after the admin gate in `admin_main.dart`.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  late int _index = _initialIndex();

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _pages.length,
      vsync: this,
      initialIndex: _index,
    )..addListener(_onTab);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Initial tab from the URL (`?tab=<index>`), clamped to a valid tab.
  int _initialIndex() {
    final raw = Uri.base.queryParameters['tab'];
    final parsed = raw == null ? null : int.tryParse(raw);
    if (parsed == null) return 0;
    return parsed.clamp(0, _pages.length - 1);
  }

  void _onTab() {
    if (_controller.indexIsChanging || _controller.index == _index) return;
    setState(() => _index = _controller.index);
    writeTabParam(_index);
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
    const SignupAllowlistView(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ServiceLocator.get<AuthService>();
    return Scaffold(
      body: Column(
        children: [
          AdminTopBar(
            controller: _controller,
            labels: [
              l10n.adminNavFeedback,
              l10n.adminNavImport,
              l10n.adminNavEngagement,
              l10n.adminNavParsing,
              l10n.adminNavRecipes,
              l10n.adminNavOps,
              l10n.adminNavGuestList,
            ],
            email: auth.currentUserEmail,
            onSignOut: auth.signOut,
          ),
          const AnomalyBanner(),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }
}
