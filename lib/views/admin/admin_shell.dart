import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/admin/engagement_view.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/admin/import_health_view.dart';

/// Top-level admin shell: a NavigationRail switching between the admin tools.
/// Reached only after the admin gate in `admin_main.dart`.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _pages = [
    FeedbackInboxView(),
    ImportHealthView(),
    EngagementView(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
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
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_index]),
        ],
      ),
    );
  }
}
