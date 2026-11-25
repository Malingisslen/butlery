/// The sheet behind a lunch place that is, or becomes, a lunchbox (BUT-2486):
/// where the box comes from (leftovers, the prep day or a suggestion), who
/// takes one and how many boxes. Drawn after the approved mockup
/// `but-2486/matlador.html` ("Lunch tisdag").
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_lunchboxes.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/list/person_check_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/menu/calendar/lunchbox_stock_section.dart';

sealed class LunchboxSheetResult {
  const LunchboxSheetResult();
}

/// "Spara matlåda".
class LunchboxSheetSave extends LunchboxSheetResult {
  const LunchboxSheetSave(this.box);
  final Lunchbox box;
}

/// "Ingen matlåda".
class LunchboxSheetRemove extends LunchboxSheetResult {
  const LunchboxSheetRemove();
}

/// How many suggestions the sheet lists; the rest are a recipe pick away.
const int kLunchboxSuggestionRows = 3;

Future<LunchboxSheetResult?> showLunchboxSheet(
  BuildContext context, {
  required DayOfWeek day,
  required String dayName,
  required Lunchbox? current,
  required String? currentTitle,
  required String? leftoversTitle,
  required List<Recipe> suggestions,
  required List<HouseholdRosterMember> roster,
  required Future<Recipe?> Function(BuildContext context) pickRecipe,
  Future<List<MealBox>?>? stockBoxes,
}) {
  return showButlerySheet<LunchboxSheetResult>(
    context: context,
    builder: (_) => LunchboxSheet(
      day: day,
      dayName: dayName,
      current: current,
      currentTitle: currentTitle,
      leftoversTitle: leftoversTitle,
      suggestions: suggestions,
      roster: roster,
      pickRecipe: pickRecipe,
      stockBoxes: stockBoxes,
    ),
  );
}

class LunchboxSheet extends StatefulWidget {
  const LunchboxSheet({
    super.key,
    required this.day,
    required this.dayName,
    required this.current,
    required this.currentTitle,
    required this.leftoversTitle,
    required this.suggestions,
    required this.roster,
    required this.pickRecipe,
    this.stockBoxes,
  });

  final DayOfWeek day;
  final String dayName;

  /// The day's box, or null for a new one.
  final Lunchbox? current;
  final String? currentTitle;

  /// The middag of the day before in the same week, or null when it has
  /// none. Unused on Monday: that middag is in another week, never read.
  final String? leftoversTitle;
  final List<Recipe> suggestions;

  /// Empty or one person for a solo account, which hides the taker list.
  final List<HouseholdRosterMember> roster;
  final Future<Recipe?> Function(BuildContext context) pickRecipe;

  /// The fridge and freezer boxes, still loading when the sheet opens; null
  /// (meal boxes off) draws no section, a null result is a failed read.
  final Future<List<MealBox>?>? stockBoxes;

  @override
  State<LunchboxSheet> createState() => _LunchboxSheetState();
}

class _LunchboxSheetState extends State<LunchboxSheet> {
  LunchboxSource? _source;
  bool _fromPreviousWeek = false;
  String? _recipeId;
  String? _recipeTitle;
  late Set<String> _takers;
  late int _portions;
  bool _portionsTouched = false;

  /// The box this lunch is taken from, or null. A stock lunch is stored as
  /// previous-week leftovers, so every check of the source looks here first.
  MealBox? _box;
  List<MealBox>? _stock;
  bool _stockLoading = false;
  bool _stockFailed = false;

  DayOfWeek? get _leftoversDay => WeeklyLunchboxes.leftoversDayFor(widget.day);

  @override
  void initState() {
    super.initState();
    final box = widget.current;
    if (box != null && box.isFromStock) _box = mealBoxOfLunch(box);
    _source = box?.source;
    _fromPreviousWeek = box?.fromPreviousWeek ?? false;
    if (box != null && !box.followsMiddag) {
      _recipeId = box.recipeId;
      _recipeTitle = box.recipeTitle ?? widget.currentTitle;
    }
    _takers = {...?box?.takerIds};
    _portions = box?.portions ?? 1;
    _portionsTouched = box != null;
    _listenToStock();
  }

  void _listenToStock() {
    final stock = widget.stockBoxes;
    if (stock == null) return;
    _stockLoading = true;
    stock.then(
      (boxes) {
        if (!mounted) return;
        setState(() {
          _stockLoading = false;
          _stockFailed = boxes == null;
          _stock = boxes;
          _portions = _portions.clamp(1, _maxPortions);
        });
      },
      onError: (Object e) {
        AppLogger.warning('Lunch sheet stock read failed: $e');
        if (mounted) {
          setState(() {
            _stockLoading = false;
            _stockFailed = true;
          });
        }
      },
    );
  }

  /// What the stepper may reach: the loaded box's remaining already leaves
  /// out this lunch's own take, so that is added back.
  int get _maxPortions {
    final box = _box;
    if (box == null) return kLunchboxMaxPortions;
    final current = widget.current;
    final own = current != null && current.mealBoxId == box.id
        ? current.portions
        : 0;
    final loaded = _stock?.where((b) => b.id == box.id).firstOrNull;
    return ((loaded?.remaining ?? 0) + own).clamp(1, kLunchboxMaxPortions);
  }

  bool get _canSave => _box != null
      ? true
      : switch (_source) {
          null => false,
          LunchboxSource.leftovers when !_fromPreviousWeek =>
            _leftoversDay != null && widget.leftoversTitle != null,
          _ => _recipeId != null,
        };

  void _setTakers(String id, bool on) => setState(() {
    on ? _takers.add(id) : _takers.remove(id);
    if (!_portionsTouched) {
      _portions = (_takers.isEmpty ? 1 : _takers.length).clamp(1, _maxPortions);
    }
  });

  Future<void> _pick(LunchboxSource source, {bool previousWeek = false}) async {
    final recipe = await widget.pickRecipe(context);
    if (recipe == null || !mounted) return;
    setState(() {
      _box = null;
      _source = source;
      _fromPreviousWeek = previousWeek;
      _recipeId = recipe.id;
      _recipeTitle = recipe.title;
    });
  }

  void _chooseSuggestion(String id, String title) => setState(() {
    _box = null;
    _source = LunchboxSource.suggestion;
    _fromPreviousWeek = false;
    _recipeId = id;
    _recipeTitle = title;
  });

  void _chooseSameWeekLeftovers() => setState(() {
    _box = null;
    _source = LunchboxSource.leftovers;
    _fromPreviousWeek = false;
    _recipeId = null;
    _recipeTitle = null;
  });

  void _chooseBox(MealBox box) => setState(() {
    _box = box;
    _source = LunchboxSource.leftovers;
    _fromPreviousWeek = true;
    _recipeId = box.recipeId;
    _recipeTitle = box.recipeTitle;
    _portions = _portions.clamp(1, _maxPortions);
  });

  Lunchbox _build() {
    final box = _box;
    if (box != null) {
      return Lunchbox.fromStock(
        box,
        portions: _portions,
        takerIds: _takers.toList()..sort(),
      );
    }
    final sameWeek = _source == LunchboxSource.leftovers && !_fromPreviousWeek;
    return Lunchbox(
      source: _source!,
      recipeId: sameWeek ? null : _recipeId,
      recipeTitle: sameWeek ? null : _recipeTitle,
      fromDay: _source == LunchboxSource.leftovers
          ? (_fromPreviousWeek ? DayOfWeek.sun : _leftoversDay)
          : null,
      fromPreviousWeek: _fromPreviousWeek,
      portions: _portions,
      takerIds: _takers.toList()..sort(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppDimensions.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space16,
                0,
                AppDimensions.space16,
                AppDimensions.space8,
              ),
              child: Text(
                l10n.lunchboxSheetTitle(widget.dayName),
                style: AppTextStyles.titleSmall.copyWith(color: cs.onSurface),
              ),
            ),
            ..._sourceRows(context),
            if (widget.roster.length > 1) ..._takerRows(context),
            _portionsRow(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space16,
                AppDimensions.space12,
                AppDimensions.space16,
                0,
              ),
              child: ActionButtons.primaryButton(
                context,
                key: const ValueKey('lunchbox-save'),
                label: l10n.lunchboxSave,
                isExpanded: true,
                onPressed: _canSave
                    ? () => Navigator.pop(context, LunchboxSheetSave(_build()))
                    : null,
              ),
            ),
            if (widget.current != null)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.space8),
                child: Center(
                  child: ButleryTextButton(
                    key: const ValueKey('lunchbox-remove'),
                    label: l10n.lunchboxRemove,
                    onPressed: () =>
                        Navigator.pop(context, const LunchboxSheetRemove()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sourceRows(BuildContext context) {
    final l10n = context.l10n;
    final monday = _leftoversDay == null;
    final leftovers = _source == LunchboxSource.leftovers && _box == null;
    final prepDay = _source == LunchboxSource.prepDay;
    final shown = widget.suggestions.take(kLunchboxSuggestionRows).toList();
    final chosenElsewhere =
        _source == LunchboxSource.suggestion &&
        _recipeId != null &&
        !shown.any((r) => r.id == _recipeId);
    return [
      ButleryItemRow(
        key: const ValueKey('lunchbox-source-leftovers'),
        leadingIcon: ButleryIcons.history,
        title: l10n.lunchboxSourceLeftovers,
        subtitle: monday
            ? (leftovers && _recipeTitle != null
                  ? _recipeTitle!
                  : l10n.lunchboxLeftoversPreviousWeek)
            : widget.leftoversTitle == null
            ? l10n.lunchboxLeftoversNone
            : l10n.lunchboxLeftoversFrom(widget.leftoversTitle!),
        enabled: monday || widget.leftoversTitle != null,
        selected: leftovers,
        showCheck: true,
        onTap: monday
            ? () => _pick(LunchboxSource.leftovers, previousWeek: true)
            : widget.leftoversTitle == null
            ? null
            : _chooseSameWeekLeftovers,
      ),
      ButleryItemRow(
        key: const ValueKey('lunchbox-source-prepday'),
        leadingIcon: ButleryIcons.refrigerator,
        title: l10n.lunchboxSourcePrepDay,
        subtitle: prepDay && _recipeTitle != null
            ? _recipeTitle!
            : l10n.lunchboxPickDish,
        selected: prepDay,
        showCheck: true,
        onTap: () => _pick(LunchboxSource.prepDay),
      ),
      if (widget.stockBoxes != null) _stockSection(),
      if (shown.isEmpty && !chosenElsewhere)
        ButleryItemRow(
          key: const ValueKey('lunchbox-source-suggestion-none'),
          leadingIcon: ButleryIcons.sparkles,
          title: l10n.lunchboxSourceSuggestion,
          subtitle: l10n.lunchboxNoSuggestions,
          enabled: false,
        ),
      for (final recipe in shown)
        _suggestionRow(context, recipe.id, recipe.title),
      if (chosenElsewhere)
        _suggestionRow(context, _recipeId!, _recipeTitle.orEmpty()),
    ];
  }

  Widget _stockSection() => LunchboxStockSection(
    loading: _stockLoading,
    failed: _stockFailed,
    stock: _stock ?? const [],
    chosen: _box,
    onSelect: _chooseBox,
  );

  Widget _suggestionRow(BuildContext context, String id, String title) {
    final l10n = context.l10n;
    return ButleryItemRow(
      key: ValueKey('lunchbox-suggestion-$id'),
      leadingIcon: ButleryIcons.sparkles,
      title: l10n.lunchboxSourceSuggestion,
      subtitle: '$title · ${l10n.lunchboxSuitsSubtitle}',
      selected: _source == LunchboxSource.suggestion && _recipeId == id,
      showCheck: true,
      onTap: () => _chooseSuggestion(id, title),
    );
  }

  List<Widget> _takerRows(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          AppDimensions.space16,
          AppDimensions.space16,
          AppDimensions.space4,
        ),
        child: SectionHeading(l10n.lunchboxTakersHeading),
      ),
      for (final member in widget.roster)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
          ),
          child: PersonCheckRow(
            key: ValueKey('lunchbox-taker-${member.memberId}'),
            name: member.displayName,
            checked: _takers.contains(member.memberId),
            onChanged: (on) => _setTakers(member.memberId, on),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          AppDimensions.space4,
          AppDimensions.space16,
          0,
        ),
        child: Text(
          l10n.lunchboxTakersHint,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    ];
  }

  Widget _portionsRow(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.lunchboxPortionsLabel,
              style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
            ),
          ),
          AppIconButton(
            key: const ValueKey('lunchbox-portions-minus'),
            icon: ButleryIcons.minus,
            semanticLabel: l10n.a11yLunchboxFewer,
            onPressed: _portions <= 1
                ? null
                : () => setState(() {
                    _portions--;
                    _portionsTouched = true;
                  }),
          ),
          SizedBox(
            width: AppDimensions.space32,
            child: Text(
              '$_portions',
              key: const ValueKey('lunchbox-portions'),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface),
            ),
          ),
          AppIconButton(
            key: const ValueKey('lunchbox-portions-plus'),
            icon: ButleryIcons.plus,
            semanticLabel: l10n.a11yLunchboxMore,
            onPressed: _portions >= _maxPortions
                ? null
                : () => setState(() {
                    _portions++;
                    _portionsTouched = true;
                  }),
          ),
        ],
      ),
    );
  }
}

/// A cap on the stepper so a slip of the thumb cannot plan twenty boxes.
const int kLunchboxMaxPortions = 12;
