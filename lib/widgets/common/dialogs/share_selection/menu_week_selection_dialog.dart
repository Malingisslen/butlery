// lib/widgets/common/dialogs/share_selection/menu_week_selection_dialog.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Single-select dialog to choose which ISO week's menu to share in a chat.
///
/// Weekly menus are keyed by ISO week (one plan per week, no named list), so
/// the picker offers a fixed range of nearby weeks — last week through two
/// weeks out — defaulting to the current week. Returns the chosen week's start
/// [DateTime] via `Navigator.pop`, or null on cancel.
class MenuWeekSelectionDialog extends StatefulWidget {
  const MenuWeekSelectionDialog({super.key});

  @override
  State<MenuWeekSelectionDialog> createState() =>
      _MenuWeekSelectionDialogState();
}

class _MenuWeekSelectionDialogState extends State<MenuWeekSelectionDialog> {
  late final List<DateTime> _weekStarts;
  late final DateTime _currentWeekStart;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = clock.now();
    _currentWeekStart = IsoWeekUtils.weekStartOf(today);
    _weekStarts = [
      IsoWeekUtils.weekStartOf(today.subtract(const Duration(days: 7))),
      _currentWeekStart,
      IsoWeekUtils.weekStartOf(today.add(const Duration(days: 7))),
      IsoWeekUtils.weekStartOf(today.add(const Duration(days: 14))),
    ];
    _selected = _currentWeekStart;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatSelectMenuWeek),
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingS,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: RadioGroup<DateTime>(
          groupValue: _selected,
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _selected = value);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _weekStarts
                .map(
                  (weekStart) => RadioListTile<DateTime>(
                    value: weekStart,
                    title: Text(_label(context, weekStart)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(context.l10n.commonShare),
        ),
      ],
    );
  }

  String _label(BuildContext context, DateTime weekStart) {
    final base = context.l10n.chatMenuWeekOption(
      IsoWeekUtils.isoWeekNumber(weekStart),
    );
    return weekStart == _currentWeekStart
        ? '$base${context.l10n.chatWeekCurrentSuffix}'
        : base;
  }
}
