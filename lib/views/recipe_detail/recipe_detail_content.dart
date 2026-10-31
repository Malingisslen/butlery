// lib/views/recipe_detail/recipe_detail_content.dart
//
// Ingredients and instructions render inline (no tabs) for immediate visibility.
// BUT-1057: RelatedRecipesSection and UsedInSection added below instructions.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/notifications/local_timer_notification_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart' as img;
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';
import 'package:butlery/widgets/cooking/step_timer_widget.dart';
import 'package:butlery/widgets/recipe/ingredient_substitution_sheet.dart';
import 'package:butlery/widgets/tagging/uncertain_tags_line.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/recipe_detail/recipe_related_recipes_section.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/views/recipe_detail/borrowed_image_frame.dart';

const double _quantityColumnWidth = 70;

/// Recipe detail content: tags, images, ingredients, and instructions rendered inline.
class RecipeDetailContent extends StatefulWidget {
  final RecipeDetailViewModel viewModel;
  final List<String> scaledIngredients;
  final int currentPortions;
  final Function(int, List<String>) onPortionChanged;
  final Function(List<String>, int) onImageTap;

  /// User allergen preferences for filtering displayed allergens
  final Set<String>? userAllergenPrefs;

  /// User dietary preferences for filtering displayed dietary info
  final Set<String>? userDietaryPrefs;

  /// Whether to show ingredient coverage indicator
  final bool showCoverage;

  /// Resolved personal tag names (tag ID → display name)
  final Map<String, String>? personalTagNames;

  const RecipeDetailContent({
    super.key,
    required this.viewModel,
    required this.scaledIngredients,
    required this.currentPortions,
    required this.onPortionChanged,
    required this.onImageTap,
    this.userAllergenPrefs,
    this.userDietaryPrefs,
    this.showCoverage = true,
    this.personalTagNames,
  });

  @override
  State<RecipeDetailContent> createState() => _RecipeDetailContentState();
}

class _RecipeDetailContentState extends State<RecipeDetailContent> {
  /// Tracks which instruction steps are completed (local state, not persisted).
  final Set<int> _completedSteps = {};

  /// Section-grouped rows (headings + lines), memoized: rebuilt only when the
  /// scaled ingredient lines change (portion scaling), not on every rebuild.
  /// Pairs the recipe's structured entries (for `section`) with the scaled
  /// display strings — see [IngredientDisplayRow.build].
  late List<IngredientDisplayRow> _ingredientRows;

  /// Tag ID → display-name map resolved on-demand from [PersonalTagService]
  /// when the parent doesn't supply [widget.personalTagNames]. Without this,
  /// `personalTagIds` never resolve to names and the personal-tags section
  /// silently never renders (the parent views pass nothing).
  Map<String, String>? _resolvedTagNames;

  RecipeDetailViewModel get viewModel => widget.viewModel;
  List<String> get scaledIngredients => widget.scaledIngredients;
  int get currentPortions => widget.currentPortions;
  Function(int, List<String>) get onPortionChanged => widget.onPortionChanged;
  Function(List<String>, int) get onImageTap => widget.onImageTap;
  Set<String>? get userAllergenPrefs => widget.userAllergenPrefs;
  Set<String>? get userDietaryPrefs => widget.userDietaryPrefs;
  bool get showCoverage => widget.showCoverage;

  /// Prefer an explicitly-supplied map; otherwise the on-demand resolution.
  Map<String, String>? get personalTagNames =>
      widget.personalTagNames ?? _resolvedTagNames;

  @override
  void initState() {
    super.initState();
    _rebuildIngredientRows();
    _resolvePersonalTagNames();
  }

  @override
  void didUpdateWidget(RecipeDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rescaling passes a new scaledIngredients list; rebuild the grouped rows.
    if (!identical(oldWidget.scaledIngredients, widget.scaledIngredients)) {
      _rebuildIngredientRows();
    }
  }

  void _rebuildIngredientRows() {
    _ingredientRows = IngredientDisplayRow.build(
      viewModel.recipe.structuredIngredients,
      scaledIngredients,
    );
  }

  /// Resolves the recipe's personal tag IDs to display names so the
  /// personal-tags section can render. Skipped when the parent already
  /// supplied names or the recipe carries no personal tags.
  Future<void> _resolvePersonalTagNames() async {
    if (widget.personalTagNames != null) return;
    final tagIds = viewModel.recipe.personalTagIds;
    if (tagIds == null || tagIds.isEmpty) return;

    try {
      final service = ServiceLocator.get<PersonalTagService>();
      final tags = await service.getTagsByIds(tagIds);
      if (!mounted) return;
      setState(() {
        _resolvedTagNames = {for (final t in tags) t.id: t.name};
      });
    } catch (_) {
      // Non-critical — section just stays hidden if resolution fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = viewModel.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasEffectiveTags) ...[
          _buildTags(context),
          const SizedBox(height: AppDimensions.space8),
        ],
        if (_hasPersonalTags) ...[
          _PersonalTagsSection(
            tagIds: viewModel.recipe.personalTagIds!,
            tagNames: personalTagNames!,
          ),
          const SizedBox(height: AppDimensions.space8),
        ],
        if (recipe.imageUrls.isNotEmpty) ...[
          _buildImageCarousel(context),
          const SizedBox(height: AppDimensions.space16),
        ],
        _buildIngredientsSection(context),
        const SizedBox(height: AppDimensions.space16),
        _buildInstructionsSection(context),
        // BUT-1057: Related-recipe sections — hidden when empty. Lists are
        // resolved in the viewmodel; the sections are purely presentational.
        RelatedRecipesSection(related: viewModel.relatedRecipes),
        UsedInSection(usedIn: viewModel.usedInRecipes),
      ],
    );
  }

  /// Ingredients section with section header, portion scaler and structured table.
  Widget _buildIngredientsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space8,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.l10n.recipeIngredients,
                  style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
                ),
              ),
              _buildPortionScaler(context),
            ],
          ),
        ),
        _buildIngredientsContent(context),
      ],
    );
  }

  /// Instructions section with section header and checkable steps.
  Widget _buildInstructionsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ButleryDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
          ),
          child: Semantics(
            header: true,
            child: Text(
              context.l10n.recipeInstructions,
              style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
            ),
          ),
        ),
        _buildInstructionsContent(context),
      ],
    );
  }

  Widget _buildIngredientsContent(BuildContext context) {
    // BUT-951: ingredient rows via ListView.builder. shrinkWrap +
    // NeverScrollable because the outer scaffold owns the scroll. Saves
    // a layout pass per row vs the eager Column children list — most
    // recipes are short so the win is modest, but for long-ingredient
    // baking recipes (50+ items) it's measurable on lower-end Android.
    // An explicit padding keeps the list from adding the system bars' insets.
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.space16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ingredientRows.length,
      itemBuilder: (context, index) => _buildDisplayRow(context, index),
    );
  }

  Widget _buildDisplayRow(BuildContext context, int index) {
    final row = _ingredientRows[index];
    if (row is IngredientHeadingRow) {
      return _buildSectionHeading(context, row.label);
    }
    final line = row as IngredientLineRow;
    // Divider between consecutive ingredient lines; a heading already provides
    // visual separation, so no divider immediately below one (or at the top).
    final prevIsLine =
        index > 0 && _ingredientRows[index - 1] is IngredientLineRow;
    return _buildIngredientRow(context, line.text, showDivider: prevIsLine);
  }

  Widget _buildSectionHeading(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.space12,
          bottom: AppDimensions.space4,
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.only(
            bottom: AppDimensions.space4,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.secondary, width: 2), // rust
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.titleSmall.copyWith(
              color: cs.onSurface,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientRow(
    BuildContext context,
    String ingredient, {
    required bool showDivider,
  }) {
    final cs = Theme.of(context).colorScheme;
    final parsed = IngredientParser.parseIngredient(ingredient);
    final allergen = _matchedAllergen(parsed.name);
    final isAllergen = allergen != null;
    final quantityWidth = math.min(
      MediaQuery.textScalerOf(context).scale(_quantityColumnWidth),
      MediaQuery.sizeOf(context).width * 0.4,
    );

    return Column(
      children: [
        if (showDivider) const ButleryDivider(spacing: 1),
        Semantics(
          label: context.l10n.a11yShowSubstitutionsFor,
          button: true,
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              onTap: () => _showSubstitutionSheet(context, parsed.name),
              child: ConstrainedBox(
                // BUT-2194: a row is a control (tap), so it is at least 48 dp tall
                // (tokens.json touchTarget).
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.space12,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // At large text every row puts the amount above the name,
                      // so the rows read the same instead of switching layout
                      // from one ingredient to the next.
                      final stacked = isLargeText(context);
                      // "salt" parses as 1, but the recipe never said 1.
                      final hasAmount =
                          parsed.unit.isNotEmpty ||
                          IngredientParser.statedQuantity(
                                ingredient,
                                parsed.quantity,
                              ) !=
                              null;
                      // "ca 2 dl", "2-3 tomater": the written amount says
                      // more than the number read from it.
                      final quantity =
                          IngredientParser.writtenAmount(ingredient) ??
                          _formatQuantity(parsed.quantity);
                      final amount = Text(
                        !hasAmount
                            ? ''
                            : parsed.unit.isNotEmpty
                            ? '$quantity ${parsed.unit}'
                            : quantity,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: stacked ? TextAlign.start : TextAlign.end,
                      );
                      final name = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isAllergen)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: AppDimensions.space4,
                                  ),
                                  child: ButleryIcon(
                                    ButleryIcons.triangleAlert,
                                    size: AppDimensions.iconSizeS,
                                    color: cs.error,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  parsed.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isAllergen ? cs.error : cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isAllergen)
                            Text(
                              context.l10n.allergenContainsLabel(allergen),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: cs.error,
                              ),
                            ),
                        ],
                      );
                      final swap = ButleryIcon(
                        ButleryIcons.swapHorizontal,
                        size: AppDimensions.iconSizeS,
                        color: AppModeColors.textDisabled(cs.brightness),
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (stacked)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasAmount) amount,
                                  name,
                                ],
                              ),
                            )
                          else ...[
                            SizedBox(width: quantityWidth, child: amount),
                            const SizedBox(width: AppDimensions.space32),
                            Expanded(child: name),
                          ],
                          swap,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Instructions tab with checkable steps.
  Widget _buildInstructionsContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final instructions = viewModel.recipe.instructions;
    if (instructions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Text(
          context.l10n.recipeNoInstructions,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // BUT-951: instructions via ListView.builder, mirrors ingredients change.
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.space16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: instructions.length,
      itemBuilder: (context, index) =>
          _buildInstructionRow(context, index, instructions),
    );
  }

  Widget _buildInstructionRow(
    BuildContext context,
    int index,
    List<String> instructions,
  ) {
    final cs = Theme.of(context).colorScheme;
    final instruction = instructions[index];
    final isCompleted = _completedSteps.contains(index);

    final isLast = index == instructions.length - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppDimensions.space16),
      child: Semantics(
        label: context.l10n.a11yToggleStepDone,
        button: true,
        toggled: isCompleted,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: () => _toggleStepCompletion(index),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepCheckbox(context, index + 1, isCompleted),
                  const SizedBox(width: AppDimensions.space16),
                  Expanded(
                    // BUT-604: duration phrases render as inline tappable
                    // chips that open the step-timer sheet — same affordance
                    // as cooking mode, no long-press discovery needed.
                    child: InlineTimerText(
                      text: instruction,
                      onTimerTap: (match) =>
                          _openStepTimer(context, instruction, match),
                      chipColor: cs.onSurface,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isCompleted ? cs.onSurfaceVariant : cs.onSurface,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// BUT-604: opens the step-timer bottom sheet pre-filled with the tapped
  /// chip's duration. Mirrors cooking mode's `_openStepTimer` — the
  /// DI-registered [StepTimerService] is reused so a running timer survives
  /// sheet re-opens and view switches.
  void _openStepTimer(
    BuildContext context,
    String instruction,
    DurationMatch match,
  ) {
    final service = ServiceLocator.get<StepTimerService>();
    final snackBars = CapturedSnackBars.capture(context);
    final timerExpired = context.l10n.timerExpired;

    showButlerySheet<void>(
      context: context,
      builder: (sheetContext) => StepTimerWidget(
        service: service,
        initialDuration: match.duration,
        sourcePhrase: instruction,
        beforeStart: () => _offerExactAlarms(sheetContext),
        onExpired: () {
          HapticFeedback.mediumImpact();
          // The messenger is captured before the sheet opens.
          snackBars.showConfirmation(timerExpired);
        },
      ),
    );
  }

  /// Only when notifications can be shown: without them an exact alarm
  /// alerts nobody.
  Future<void> _offerExactAlarms(BuildContext context) async {
    final permissions = ServiceLocator.tryGet<NotificationPermissionService>();
    if (permissions != null && !await permissions.notificationsAllowed()) {
      return;
    }
    if (!context.mounted) return;
    await ServiceLocator.tryGet<LocalTimerNotificationService>()
        ?.offerExactAlarmsOnce(context);
  }

  Widget _buildStepCheckbox(
    BuildContext context,
    int stepNumber,
    bool isCompleted,
  ) {
    final cs = Theme.of(context).colorScheme;

    return ButleryAnimatedDisc(
      duration: AppMotion.micro.respectingMotion(context),
      size: 28,
      color: isCompleted ? cs.primary : cs.surfaceContainerHighest,
      // Done: control.checked.background, ink in both modes (tokens.json:
      // 145-148). Not done: a text.primary edge, paper on dark.
      borderColor: isCompleted ? cs.primary : cs.onSurface,
      borderWidth: 2,
      child: Center(
        child: isCompleted
            ? ButleryIcon(
                ButleryIcons.check,
                size: AppDimensions.iconSizeS,
                color: cs.onPrimary,
              )
            : Text(
                '$stepNumber',
                style: AppTextStyles.labelMediumBold.copyWith(
                  color: cs.onSurface,
                ),
              ),
      ),
    );
  }

  /// The tracked allergen this ingredient name matches, if the recipe is
  /// known to contain it. The match is on the name, so it is a hint, and the
  /// row says it in words rather than leaving a bare icon.
  String? _matchedAllergen(String ingredientName) {
    if (userAllergenPrefs == null || userAllergenPrefs!.isEmpty) return null;
    final allergenStatus = viewModel.recipe.tagResult?.allergenStatus;
    if (allergenStatus == null) return null;

    // Normalize both sides to ASCII for case-insensitive Swedish matching
    final nameNormalized = SwedishCharacterNormalizer.normalize(ingredientName);
    for (final entry in allergenStatus.entries) {
      if (entry.value != TriState.contains) continue;
      if (!userAllergenPrefs!.contains(entry.key)) continue;
      final keyNormalized = SwedishCharacterNormalizer.normalize(entry.key);
      if (nameNormalized.contains(keyNormalized)) return entry.key;
    }
    return null;
  }

  /// Formats a quantity for display: common fractions as glyphs (0.75 →
  /// "¾", 1.5 → "1 ½"), anything else with sv-SE decimal comma.
  String _formatQuantity(double quantity) {
    return TextFormatting.toSwedishHalfFraction(quantity);
  }

  void _showSubstitutionSheet(BuildContext context, String ingredientName) {
    if (ingredientName.isEmpty) return;
    showButlerySheet<void>(
      context: context,
      maxHeightFraction: 0.6,
      builder: (_) => IngredientSubstitutionSheet(
        ingredientName: ingredientName,
      ),
    );
  }

  void _toggleStepCompletion(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  /// Whether there are effective tags to display.
  bool get _hasEffectiveTags {
    final recipe = viewModel.recipe;
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return effectiveTags.isNotEmpty;
  }

  /// Whether there are personal tags to display.
  bool get _hasPersonalTags {
    final tagIds = viewModel.recipe.personalTagIds;
    if (tagIds == null || tagIds.isEmpty) return false;
    if (personalTagNames == null || personalTagNames!.isEmpty) return false;
    return tagIds.any((id) => personalTagNames!.containsKey(id));
  }

  /// Gets the top 5 effective tags with smart priority.
  List<String> get _topEffectiveTags {
    final recipe = viewModel.recipe;
    final autoTags = recipe.tagResult?.tags ?? <String>{};
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};
    final removedTags = recipe.tagOverrides?.removedTags ?? <String>{};
    final effectiveTags = autoTags.union(userAddedTags).difference(removedTags);
    return TagDisplayUtils.getTopTags(effectiveTags, userAddedTags, limit: 5);
  }

  Widget _buildTags(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recipe = viewModel.recipe;
    final userAddedTags = recipe.tagOverrides?.addedTags ?? <String>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ButleryIcon(
                ButleryIcons.tag,
                color: cs.onSurface,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.space8),
              Text(
                context.l10n.recipeTags,
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Wrap(
            spacing: AppDimensions.space4,
            runSpacing: AppDimensions.space4,
            children: _topEffectiveTags.map((tag) {
              final isUserAdded = userAddedTags.contains(tag);
              final displayName = TagDisplayUtils.getDisplayName(tag);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space4,
                  vertical: AppDimensions.space4,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(
                    color: isUserAdded ? cs.onSurface : cs.outlineVariant,
                    width: isUserAdded ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  displayName,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              );
            }).toList(),
          ),
          if (UncertainTagsLine.appliesTo(recipe.tagResult)) ...[
            const SizedBox(height: AppDimensions.space8),
            UncertainTagsLine(tagResult: recipe.tagResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final credit = BorrowedImageCredit.forGallery(
      imageUrls: viewModel.recipe.imageUrls,
      sourceUrl: viewModel.recipe.sourceUrl,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
            child: Row(
              children: [
                ButleryIcon(
                  ButleryIcons.image,
                  color: cs.onSurface,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.space8),
                Text(
                  context.l10n.recipeImagesTitle,
                  style: AppTextStyles.titleMedium,
                ),
                const Spacer(),
                Text(
                  context.l10n.recipeImageCount(
                    viewModel.recipe.imageUrls.length,
                  ),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          if (credit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space16,
                0,
                AppDimensions.space16,
                AppDimensions.space8,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: credit,
              ),
            ),
          // Image carousel
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: img.UniversalImageManager.recipeDetail(
              imageUrls: viewModel.recipe.imageUrls,
              size: ImageSize.large,
              showNavigationDots: true,
              showImageCounter: true,
              semanticsLabel: viewModel.recipe.title,
              onImageTap: (index) =>
                  onImageTap(viewModel.recipe.imageUrls, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionScaler(BuildContext context) {
    return PortionScaler(
      originalPortions: viewModel.recipe.portions ?? 1,
      originalIngredients: viewModel.recipe.ingredients,
      // BUT-444: scale on persisted amounts; falls back per-entry to the
      // string path for legacy recipes (raw-only entries).
      structuredIngredients: viewModel.recipe.structuredIngredients,
      // BUT-1322: mount at the parent's portion state — the household-size
      // default on first open (RecipeDetailActions.initializeScaling), or the
      // user's manual choice after an override. Base stays recipe.portions.
      initialPortions: currentPortions,
      onPortionChanged: onPortionChanged,
      minPortions: 1,
      maxPortions: 20,
      compact: true,
    );
  }
}

/// Collapsible section for personal tags display.
class _PersonalTagsSection extends StatefulWidget {
  final List<String> tagIds;
  final Map<String, String> tagNames;

  const _PersonalTagsSection({
    required this.tagIds,
    required this.tagNames,
  });

  @override
  State<_PersonalTagsSection> createState() => _PersonalTagsSectionState();
}

class _PersonalTagsSectionState extends State<_PersonalTagsSection> {
  bool _isExpanded = false;
  static const int _collapsedLimit = 3;

  List<String> get _resolvedNames {
    return widget.tagIds
        .where((id) => widget.tagNames.containsKey(id))
        .map((id) => widget.tagNames[id]!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = _resolvedNames;
    if (names.isEmpty) return const SizedBox.shrink();

    final hasOverflow = names.length > _collapsedLimit;
    final displayNames = _isExpanded
        ? names
        : names.take(_collapsedLimit).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          Row(
            children: [
              ButleryIcon(
                ButleryIcons.tag,
                color: cs.onSurface,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: Text(
                  context.l10n.recipePersonalTags,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (hasOverflow)
                ButleryTextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  dense: true,
                  icon: _isExpanded
                      ? ButleryIcons.chevronUp
                      : ButleryIcons.chevronDown,
                  label: _isExpanded
                      ? context.l10n.commonHide
                      : context.l10n.commonShowAllCount(names.length),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          // Tags
          Wrap(
            spacing: AppDimensions.space4,
            runSpacing: AppDimensions.space4,
            // The overflow chip's hit area makes its run taller than the
            // tags; centring keeps the chips level with each other.
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...displayNames.map((name) => _buildPersonalTag(context, name)),
              if (!_isExpanded && hasOverflow)
                _buildOverflowIndicator(
                  context,
                  names.length - _collapsedLimit,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTag(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelMedium.copyWith(
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildOverflowIndicator(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;

    // BUT-2218: the chip stays small; its target is 48 dp tall and wide
    // (tokens.json touchTarget), the chip centred inside it.
    return ButleryTapTarget(
      semanticLabel: context.l10n.a11yShowMore,
      onTap: () => setState(() => _isExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          context.l10n.commonMoreCount(count),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppModeColors.textSecondaryOnRaised(cs.brightness),
          ),
        ),
      ),
    );
  }
}
