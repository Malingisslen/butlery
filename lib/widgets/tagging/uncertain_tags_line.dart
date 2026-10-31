import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// "Osäkra taggar, 3 ingredienser okända" under a recipe's tags when too few
/// of its ingredients are known for the tags to be sure (Malin 2026-10-30,
/// kärnflöde steg 5 beslut 5). Shown in the recipe detail only.
class UncertainTagsLine extends StatelessWidget {
  final TagResult tagResult;

  const UncertainTagsLine({super.key, required this.tagResult});

  static bool appliesTo(TagResult? tagResult) =>
      tagResult != null &&
      tagResult.unknownIngredients.isNotEmpty &&
      tagResult.coverage < TaggingThresholds.proteinCoverage;

  @override
  Widget build(BuildContext context) {
    return InlineWarning(
      icon: ButleryIcons.triangleAlert,
      color: context.modeColors.warning,
      textColor: AppModeColors.textWarning(Theme.of(context).brightness),
      text: context.l10n.tagResultUncertainTags(
        tagResult.unknownIngredients.length,
      ),
    );
  }
}
