/// BUT-1611: collapsible "who's home this week" overview for the weekly-menu
/// calendar. Collapsed, it states who is away part of the week; expanded, it
/// shows a READ-ONLY member × day status grid (present the whole day = filled).
/// Editing is per meal on the individual slot cells — the grid is a glanceable
/// week summary, not an editor, so it can't flatten per-slot nuance. Rendered
/// only for a household with family members.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/family/family_widgets.dart';

class PresenceOverview extends StatelessWidget {
  final List<HouseholdRosterMember> roster;
  final WeeklyMenuPlan plan;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const PresenceOverview({
    super.key,
    required this.roster,
    required this.plan,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    // Members away for at least one whole day this week.
    final away = roster
        .where(
          (m) => DayOfWeek.values.any(
            (d) => !plan.isPresentWholeDay(d, m.memberId),
          ),
        )
        .toList();
    final summary = away.isEmpty
        ? l10n.menuPresenceSummaryAllHome
        : l10n.menuPresenceSummaryAway(
            away.map((m) => m.displayName).join(', '),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingSm,
        AppDimensions.spacingMd,
        0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: l10n.menuPresenceSummaryTitle,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.home_outlined, size: 15, color: cs.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summary,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) _buildGrid(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header: day abbreviations.
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 92),
                for (final day in DayOfWeek.values)
                  Expanded(
                    child: Text(
                      day.displayLabel,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final member in roster)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Row(
                      children: [
                        FamilyAvatar(
                          name: member.displayName,
                          color: parseAvatarColor(member.avatarColor),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            member.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final day in DayOfWeek.values)
                    Expanded(
                      child: _GridCell(
                        present: plan.isPresentWholeDay(day, member.memberId),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Read-only whole-day status marker. Editing is per meal on the slot cells;
/// this grid is a glanceable visual summary (the collapsed sentence above is
/// the screen-reader-accessible form), so the cell is decorative.
class _GridCell extends StatelessWidget {
  final bool present;

  const _GridCell({required this.present});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: present ? cs.primary : Colors.transparent,
            border: Border.all(
              color: present ? cs.primary : cs.outlineVariant,
              width: 1.5,
            ),
          ),
          child: present
              ? Icon(Icons.check, size: 11, color: cs.onPrimary)
              : null,
        ),
      ),
    );
  }
}
