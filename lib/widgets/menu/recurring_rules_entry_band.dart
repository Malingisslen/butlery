// BUT-2490: the band at the top of the week menu that opens "Fasta dagar".
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/views/recurring_day_rules/recurring_day_rules_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

/// Opens the rule list; shows how many rules there are.
class RecurringRulesEntryBand extends StatefulWidget {
  const RecurringRulesEntryBand({super.key});

  @override
  State<RecurringRulesEntryBand> createState() =>
      _RecurringRulesEntryBandState();
}

class _RecurringRulesEntryBandState extends State<RecurringRulesEntryBand> {
  OwnProfileReader? _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.tryGet<OwnProfileReader>()
      ?..addListener(_onChanged);
  }

  @override
  void dispose() {
    _userService?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count =
        _userService?.currentUserProfile?.recurringDayRules.length ?? 0;
    return ButleryListRow(
      label: context.l10n.recurringRulesTitle,
      leading: ButleryIcons.refreshCw,
      count: count,
      countLabel: context.l10n.recurringRulesBandCount(count),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const RecurringDayRulesView()),
      ),
    );
  }
}
