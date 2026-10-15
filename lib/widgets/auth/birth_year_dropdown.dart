import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// The year-only birth year question (GDPR Art 8) of onboarding and the
/// guest start. Year granularity is sufficient per Swedish DPA guidance and
/// minimises PII collection vs. a full DOB.
class BirthYearDropdown extends StatelessWidget {
  const BirthYearDropdown({
    required this.selected,
    required this.onChanged,
    this.dropdownKey,
    super.key,
  });

  final int? selected;
  final ValueChanged<int?>? onChanged;
  final Key? dropdownKey;

  @override
  Widget build(BuildContext context) {
    // No default is pre-selected: the age gate requires a deliberate age
    // declaration (ADR-0001 / Dataskyddslag 2 kap. 4 §), so the dropdown
    // starts on a "choose a year" hint.
    final currentYear = clock.now().year;
    // Range: oldest = 100 yrs ago, youngest = age 13. The youngest OFFERED year
    // sits deliberately *below* the 15 floor so a 13- or 14-year-old can declare
    // their real age and get the polite "too young" screen — the 15 threshold is
    // enforced after selection, not by the picker bounds.
    final youngestYear = currentYear - 13;
    final oldestYear = currentYear - 100;
    final years = [for (int y = youngestYear; y >= oldestYear; y--) y];

    // Dropdown keeps the interaction quick and avoids a scrolling wheel
    // that fails the accessibility contract on wide layouts.
    final label = context.l10n.onboardingAgeGateBirthYearLabel;
    // The label stands above the box as the drawn screens set it, and the
    // field takes its name from a Semantics label so it is read once.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: SectionHeading(label)),
        const SizedBox(height: AppDimensions.space8),
        ButleryDropdown<int>(
          key: dropdownKey,
          square: true,
          semanticLabel: label,
          hint: context.l10n.onboardingAgeGateBirthYearHint,
          value: years.contains(selected) ? selected : null,
          options: [
            for (final y in years)
              ButleryDropdownOption<int>(value: y, label: y.toString()),
          ],
          onChanged: onChanged == null ? null : (y) => onChanged!(y),
        ),
      ],
    );
  }
}
