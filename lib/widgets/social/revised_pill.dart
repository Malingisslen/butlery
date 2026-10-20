import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';

/// "Omprövat": the decision was changed when the case was reopened.
class RevisedPill extends StatelessWidget {
  const RevisedPill({super.key});

  @override
  Widget build(BuildContext context) =>
      UnifiedBadge.status(label: context.l10n.decisionStatusRevised);
}

/// [status] with the "Omprövat" pill beside it when [revised].
Widget withRevisedPill(Widget status, {required bool revised}) => revised
    ? Wrap(
        alignment: WrapAlignment.end,
        spacing: AppDimensions.space4,
        runSpacing: AppDimensions.space4,
        children: [status, const RevisedPill()],
      )
    : status;
