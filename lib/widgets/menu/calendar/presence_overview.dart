/// BUT-1611: collapsible "who's home this week" overview for the weekly-menu
/// calendar. Collapsed, it states who is away part of the week; expanded, it
/// shows a READ-ONLY member × day status grid (present the whole day = filled).
/// Editing is per meal on the individual slot cells — the grid is a glanceable
/// week summary, not an editor, so it can't flatten per-slot nuance. Rendered
/// only for a household with family members.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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

  /// "Elias", "Elias och Petra", "Elias, Petra och Maja".
  static String _names(List<String> names) {
    if (names.length < 2) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} och ${names.last}';
  }

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
            _names([for (final m in away) m.displayName]),
          );
    final initials = distinctInitials([
      for (final m in roster) m.displayName,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: l10n.menuPresenceSummaryTitle,
            child: Material(
              type: MaterialType.transparency,
              child: PressFill(
                surface: PressSurface.base,
                child: InkWell(
                  onTap: onToggleExpanded,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppDimensions.minTouchTarget,
                    ),
                    child: Row(
                      children: [
                        if (away.isEmpty)
                          ButleryIcon(
                            ButleryIcons.house,
                            size: AppDimensions.iconSizeM,
                            color: cs.secondary,
                          )
                        else
                          _AwayFaces(
                            members: away,
                            initials: [
                              for (final m in away) initials[roster.indexOf(m)],
                            ],
                          ),
                        const SizedBox(width: AppDimensions.space12),
                        Expanded(
                          child: Text(
                            summary,
                            style: AppTextStyles.labelLargeBold.copyWith(
                              color: cs.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButleryIcon(
                          expanded
                              ? ButleryIcons.chevronUp
                              : ButleryIcons.chevronDown,
                          size: AppDimensions.iconSizeM,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
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
    final initials = distinctInitials([
      for (final m in roster) m.displayName,
    ]);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space8,
        0,
        AppDimensions.space8,
        AppDimensions.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header: day abbreviations.
          Padding(
            padding: AppDimensions.paddingOnlyBottom4,
            child: Row(
              children: [
                const SizedBox(width: 92),
                for (final day in DayOfWeek.values)
                  Expanded(
                    child: Text(
                      day.displayLabel,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.overline.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var m = 0; m < roster.length; m++)
            Padding(
              padding: AppDimensions.paddingVertical4,
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Row(
                      children: [
                        FamilyAvatar(
                          name: roster[m].displayName,
                          color: parseAvatarColor(
                            context,
                            roster[m].avatarColor,
                          ),
                          size: AppDimensions.iconSize18,
                          initials: initials[m],
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        Expanded(
                          child: Text(
                            roster[m].displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall.copyWith(
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
                        present: plan.isPresentWholeDay(
                          day,
                          roster[m].memberId,
                        ),
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
      padding: AppDimensions.paddingAll4,
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
              ? ButleryIcon(
                  ButleryIcons.check,
                  size: AppDimensions.iconSizeXs,
                  color: cs.onPrimary,
                )
              : null,
        ),
      ),
    );
  }
}

/// The faces of the members who are away, overlapping, at most three.
class _AwayFaces extends StatelessWidget {
  const _AwayFaces({required this.members, required this.initials});

  final List<HouseholdRosterMember> members;
  final List<String> initials;

  static const double _face = 26;
  static const int _max = 3;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(_max).toList();
    const step = _face - AppDimensions.space8;
    return ExcludeSemantics(
      child: SizedBox(
        width: _face + (shown.length - 1) * step,
        height: _face,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              PositionedDirectional(
                start: i * step,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: FamilyAvatar(
                    name: shown[i].displayName,
                    color: parseAvatarColor(context, shown[i].avatarColor),
                    size: _face,
                    initials: initials[i],
                    circular: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
