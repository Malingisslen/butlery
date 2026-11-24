// lib/widgets/menu/day_suggestion_sheet.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/day_suggestion_picker.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_generator/strict_safe_pool.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// Offers a handful of dishes for an empty menu day (BUT-2497). Returns the
/// dish the user picked; placing it is the caller's job, so the usual
/// confirmation before a manual add still runs.
class DaySuggestionSheet {
  static Future<Recipe?> show(
    BuildContext context, {
    required WeeklyMenuPlan plan,
    required DayOfWeek day,
    required MealSlot slot,
    @visibleForTesting Future<List<Recipe>> Function()? readPoolOverride,
  }) {
    return showButlerySheet<Recipe>(
      context: context,
      builder: (_) => _SheetContent(
        plan: plan,
        day: day,
        slot: slot,
        readPool: readPoolOverride ?? readPool,
      ),
    );
  }

  static Future<List<Recipe>> readPool() async => StrictSafePool.read(
    menuService: ServiceLocator.get<MenuService>(),
    recipeService: ServiceLocator.get<UnifiedRecipeService>(),
    userService: ServiceLocator.get<OwnProfileReader>(),
  );
}

class _SheetContent extends StatefulWidget {
  const _SheetContent({
    required this.plan,
    required this.day,
    required this.slot,
    required this.readPool,
  });

  final Future<List<Recipe>> Function() readPool;
  final WeeklyMenuPlan plan;
  final DayOfWeek day;
  final MealSlot slot;

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  List<Recipe>? _pool;
  List<Recipe> _cards = [];
  final Set<String> _locked = {};
  final Set<String> _shown = {};
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    widget
        .readPool()
        .then((pool) {
          if (!mounted) return;
          setState(() => _pool = pool);
          _draw();
        })
        .catchError((Object _) {
          // No pool means no suggestions: say so rather than spin forever.
          if (mounted) setState(() => _pool = const []);
        });
  }

  void _draw() {
    final pool = _pool;
    if (pool == null) return;
    final kept = _cards.where((r) => _locked.contains(r.id)).toList();
    final fresh = DaySuggestionPicker.pick(
      pool: pool,
      plan: widget.plan,
      day: widget.day,
      slot: widget.slot,
      now: clock.now(),
      locked: kept,
      shown: _shown,
    );
    setState(() {
      _cards = [...kept, ...fresh];
      _shown.addAll(fresh.map((r) => r.id));
      if (!_cards.any((r) => r.id == _selectedId)) _selectedId = null;
    });
  }

  String get _dayName {
    final date = widget.plan.weekStartDate.add(
      Duration(days: widget.day.index),
    );
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.EEEE(locale).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final pool = _pool;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          0,
          AppDimensions.space16,
          AppDimensions.space16,
        ),
        child: pool == null
            ? const SizedBox(height: 160, child: Center(child: PlateLine()))
            : _cards.isEmpty
            ? _empty(context)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.menuSuggestTitle(_dayName),
                    style: AppTextStyles.sectionHeader.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    l10n.menuSuggestIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  for (final recipe in _cards) ...[
                    _card(context, recipe),
                    const SizedBox(height: AppDimensions.space8),
                  ],
                  const SizedBox(height: AppDimensions.space8),
                  ActionButtons.secondaryButton(
                    context,
                    label: l10n.menuSuggestShowOthers,
                    icon: ButleryIcons.shuffle,
                    isExpanded: true,
                    onPressed: _draw,
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  ActionButtons.primaryButton(
                    context,
                    label: _selectedId == null
                        ? l10n.menuSuggestPickOne
                        : l10n.menuSuggestPlaceOnDay(_dayName),
                    isExpanded: true,
                    onPressed: _selectedId == null
                        ? null
                        : () => Navigator.pop(
                            context,
                            _cards.firstWhere((r) => r.id == _selectedId),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card(BuildContext context, Recipe recipe) {
    final cs = Theme.of(context).colorScheme;
    final locked = _locked.contains(recipe.id);
    final selected = _selectedId == recipe.id;
    final meta = [
      if (recipe.timeMinutes != null) '${recipe.timeMinutes} min',
      ?recipe.lastCookedText,
    ].join(' · ');
    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: PressFill(
        surface: PressSurface.raised,
        child: InkWell(
          key: ValueKey('suggestion-card-${recipe.id}'),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          onTap: () => setState(() => _selectedId = recipe.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              AppDimensions.space8,
              AppDimensions.space4,
              AppDimensions.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                AppIconButton(
                  key: ValueKey('suggestion-lock-${recipe.id}'),
                  semanticLabel: locked
                      ? context.l10n.menuSuggestUnlockCard
                      : context.l10n.menuSuggestLockCard,
                  icon: locked ? ButleryIcons.lock : ButleryIcons.unlock,
                  onPressed: () => setState(() {
                    locked ? _locked.remove(recipe.id) : _locked.add(recipe.id);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ButleryIcon(ButleryIcons.searchOff),
          const SizedBox(height: AppDimensions.space12),
          Text(
            l10n.menuSuggestEmptyTitle,
            style: AppTextStyles.sectionHeader.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(l10n.menuSuggestEmptyBody, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
