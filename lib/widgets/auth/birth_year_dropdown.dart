import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
    return PressFill(
      surface: PressSurface.base,
      child: DropdownButtonFormField<int>(
        icon: const ButleryIcon(ButleryIcons.chevronDown),
        iconEnabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
        iconDisabledColor: AppModeColors.textDisabled(
          Theme.of(context).brightness,
        ),
        key: dropdownKey,
        initialValue: years.contains(selected) ? selected : null,
        isExpanded: true,
        hint: Text(context.l10n.onboardingAgeGateBirthYearHint),
        decoration: InputDecoration(
          labelText: context.l10n.onboardingAgeGateBirthYearLabel,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final y in years)
            DropdownMenuItem<int>(value: y, child: Text(y.toString())),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
