// BUT-2490: one saved weekly rule. A day and meal that already has a rule
// opens that rule, so there is one way to edit and one way to add.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/recurring_day_rules/recurring_day_rule_store.dart';
import 'package:butlery/viewmodels/recurring_day_rules_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/section_heading.dart';

/// The order the chips are drawn in.
const List<RecurringFood> _foodOrder = [
  RecurringFood.fisk,
  RecurringFood.kyckling,
  RecurringFood.vegetariskt,
  RecurringFood.soppa,
  RecurringFood.pasta,
  RecurringFood.tacos,
];

const List<MealSlot> _meals = [MealSlot.lunch, MealSlot.middag];

class RecurringDayRuleEditorView extends StatefulWidget {
  const RecurringDayRuleEditorView({
    this.initialDay,
    this.initialMeal = MealSlot.middag,
    this.viewModel,
    this.scope = const RecurringRuleScope.personal(),
    super.key,
  });

  final DayOfWeek? initialDay;
  final MealSlot initialMeal;

  /// The list's model when opened from it; without one the editor builds its
  /// own from [scope].
  final RecurringDayRulesViewModel? viewModel;

  final RecurringRuleScope scope;

  @override
  State<RecurringDayRuleEditorView> createState() =>
      _RecurringDayRuleEditorViewState();
}

class _RecurringDayRuleEditorViewState
    extends State<RecurringDayRuleEditorView> {
  late final RecurringDayRulesViewModel _vm;
  late DayOfWeek _day;
  late MealSlot _meal;
  RecurringFood? _food;
  bool _quick = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vm =
        widget.viewModel ??
        RecurringDayRulesViewModel(store: widget.scope.createStore());
    _day = widget.initialDay ?? DayOfWeek.mon;
    _meal = widget.initialMeal;
    _loadExisting();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final existing = _vm.ruleAt(_day, _meal);
    _food = existing?.food;
    _quick = existing?.quick ?? false;
  }

  void _pickSlot({DayOfWeek? day, MealSlot? meal}) => setState(() {
    _day = day ?? _day;
    _meal = meal ?? _meal;
    _loadExisting();
  });

  Future<void> _save() async {
    final l = context.l10n;
    if (_food == null && !_quick) {
      SnackBarUtils.showFailure(context, what: l.recurringRuleNeedChoice);
      return;
    }
    setState(() => _saving = true);
    // A paused rule stays paused when its sort is changed.
    final paused = _vm.ruleAt(_day, _meal)?.paused ?? false;
    final rule = RecurringDayRule.create(
      day: _day,
      meal: _meal,
      food: _food,
      quick: _quick,
    );
    final ok = await _vm.save(paused ? rule.copyWith(paused: true) : rule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      SnackBarUtils.showFailure(
        context,
        what: _vm.error ?? l.recurringRuleSaveFailed,
      );
    }
  }

  Widget _section(String title, List<Widget> chips) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.space24,
          bottom: AppDimensions.space8,
        ),
        child: SectionHeading(title),
      ),
      Wrap(
        spacing: AppDimensions.space8,
        runSpacing: AppDimensions.space8,
        children: chips,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ButleryPage.undersida(
      title: l.recurringRulesNew,
      backTo: l.recurringRulesTitle,
      // A form: Spara sits in the footer and the tab bar steps aside.
      showTabBar: false,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: ButleryPageBody.margin(context, top: AppDimensions.space8),
          child: FormButton(
            label: l.commonSave,
            expand: true,
            busy: _saving,
            onPressed: _saving ? null : () => unawaited(_save()),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: ButleryPageBody.margin(
          context,
          bottom: AppDimensions.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(l.recurringRuleSectionDay, [
              for (final day in DayOfWeek.values)
                ButleryChoiceChip(
                  label: l.recurringRuleDayShort(day.name),
                  selected: day == _day,
                  onSelected: (_) => _pickSlot(day: day),
                ),
            ]),
            _section(l.recurringRuleSectionMeal, [
              for (final meal in _meals)
                ButleryChoiceChip(
                  label: meal == MealSlot.lunch
                      ? l.recurringRuleMealLunch
                      : l.recurringRuleMealDinner,
                  selected: meal == _meal,
                  onSelected: (_) => _pickSlot(meal: meal),
                ),
            ]),
            _section(l.recurringRuleSectionFood, [
              for (final food in _foodOrder)
                ButleryChoiceChip(
                  label: l.recurringRuleFoodLabel(food.name),
                  selected: food == _food,
                  // A second tap clears it, so "Snabbt" can stand alone.
                  onSelected: (_) =>
                      setState(() => _food = food == _food ? null : food),
                ),
            ]),
            _section(l.recurringRuleSectionEvening, [
              ButleryChoiceChip(
                label: l.recurringRuleQuickLabel,
                selected: _quick,
                onSelected: (_) => setState(() => _quick = true),
              ),
              ButleryChoiceChip(
                label: l.recurringRuleAnyEvening,
                selected: !_quick,
                onSelected: (_) => setState(() => _quick = false),
              ),
            ]),
            const SizedBox(height: AppDimensions.space24),
            Text(
              widget.scope.isGroup
                  ? l.recurringRuleEditorNoteGroup
                  : l.recurringRuleEditorNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
