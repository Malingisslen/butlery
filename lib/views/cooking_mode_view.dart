// lib/views/cooking_mode_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';
import 'package:butlery/widgets/cooking/step_timer_widget.dart';
import 'package:butlery/widgets/cooking/substitution_bottom_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Full-screen landscape cooking mode with ingredients left, instructions right.
/// Keeps screen awake and forces landscape orientation while active.
class CookingModeView extends StatefulWidget {
  final Recipe recipe;

  const CookingModeView({super.key, required this.recipe});

  @override
  State<CookingModeView> createState() => _CookingModeViewState();
}

class _CookingModeViewState extends State<CookingModeView> {
  // Hoisted out of build() so initState/dispose can wire the BUT-408
  // session broadcast lifecycle alongside wakelock/orientation setup.
  late final CookingModeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CookingModeViewModel(recipe: widget.recipe);
    // Force landscape and keep screen awake
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    // Hide system UI for immersive cooking experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // BUT-408: broadcast "lagar just nu" to friend groups. Fire-and-forget
    // — the VM swallows errors so a failed broadcast never blocks the cook.
    _vm.onEnter();
  }

  @override
  void dispose() {
    // BUT-408: clear broadcast BEFORE disposing the VM. onExit() reads no
    // VM state, so the ordering is purely about signalling intent.
    _vm.onExit();
    _vm.dispose();
    // Restore all orientations and screen sleep
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CookingModeViewModel>.value(
      value: _vm,
      child: const _CookingModeContent(),
    );
  }
}

class _CookingModeContent extends StatelessWidget {
  const _CookingModeContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<CookingModeViewModel>();

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, vm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel: ingredients (~35%)
                  Expanded(
                    flex: 35,
                    child: _IngredientsPanel(vm: vm),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    color: cs.surface.withValues(alpha: 0.2),
                  ),
                  // Right panel: instructions (~65%)
                  Expanded(
                    flex: 65,
                    child: _InstructionsPanel(vm: vm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CookingModeViewModel vm) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        border: Border(
          bottom: BorderSide(
            color: cs.surface.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Recipe title
          Expanded(
            child: Text(
              vm.title.toLowerCase(),
              style: AppTextStyles.headerTitle.copyWith(
                color: cs.onPrimary,
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Font size toggle
          ColoredBox(
            color: cs.surface,
            child: TappableWrapper(
              onTap: () => vm.cycleFontScale(),
              semanticLabel: context.l10n.a11yCookingModeFontScale,
              child: Text(
                'A${vm.fontScale == 1.0 ? '' : vm.fontScale == 1.25 ? '+' : '++'}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          // Close button
          ColoredBox(
            color: cs.surface,
            child: TappableWrapper(
              onTap: () => Navigator.pop(context),
              semanticLabel: context.l10n.a11yCookingModeClose,
              child: Icon(
                Icons.close,
                color: cs.primary,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left panel displaying scaled ingredients with portion controls.
class _IngredientsPanel extends StatelessWidget {
  final CookingModeViewModel vm;

  const _IngredientsPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portion scaler controls
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                  color: cs.surface.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  context.l10n.cookingModePortions,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                _buildPortionButton(
                  context,
                  icon: Icons.remove,
                  onPressed:
                      vm.currentPortions > CookingModeViewModel.minPortions
                          ? () => vm.updatePortions(vm.currentPortions - 1)
                          : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                  ),
                  child: Text(
                    '${vm.currentPortions}',
                    style: AppTextStyles.groupTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
                _buildPortionButton(
                  context,
                  icon: Icons.add,
                  onPressed:
                      vm.currentPortions < CookingModeViewModel.maxPortions
                          ? () => vm.updatePortions(vm.currentPortions + 1)
                          : null,
                ),
              ],
            ),
          ),
          // Ingredient list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingSm,
              ),
              itemCount: vm.scaledIngredients.length,
              itemBuilder: (context, index) {
                final ingredientText = vm.scaledIngredients[index];
                return Semantics(
                  label: context.l10n.a11yCookingModeIngredient(ingredientText),
                  // BUT-202: long-press → substitution suggestions sheet.
                  child: GestureDetector(
                    onLongPress: () =>
                        _showSubstitutionSheet(context, vm, index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingTight,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsetsDirectional.only(
                                top: 8, end: 12),
                            decoration: BoxDecoration(
                              color: cs.onPrimary,
                              shape: BoxShape.rectangle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ingredientText,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// BUT-202: Fetches substitution suggestions and opens the bottom sheet.
  /// If the user selects a substitute, route the replace through
  /// [UnifiedRecipeService.updateIngredient] — reuses the existing edit
  /// path, no new repository method this sprint.
  Future<void> _showSubstitutionSheet(
    BuildContext context,
    CookingModeViewModel vm,
    int index,
  ) async {
    final service = ServiceLocator.tryGet<SubstitutionSuggestionService>();
    final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
    final ingredientLine = vm.scaledIngredients[index];

    final suggestions = service == null
        ? const <IngredientSubstitution>[]
        : await service.suggestFor(ingredientLine);

    if (!context.mounted) return;

    final chosen = await SubstitutionBottomSheet.show(
      context: context,
      ingredientName: ingredientLine,
      suggestions: suggestions,
    );

    if (chosen == null) return;
    if (!context.mounted) return;

    // Graceful degradation: if the recipe service isn't resolvable (e.g. in
    // a constrained test harness), log and toast rather than throwing.
    if (recipeService == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.cookingModeOpenEditToSwap),
        ),
      );
      return;
    }

    await recipeService.updateIngredient(
      vm.recipe.id,
      index,
      chosen.name,
    );
  }

  Widget _buildPortionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    final label = icon == Icons.remove
        ? context.l10n.portionDecrease
        : context.l10n.portionIncrease;
    return Semantics(
      label: label,
      button: true,
      enabled: isEnabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: AppDimensions.minTouchTarget,
            height: AppDimensions.minTouchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: isEnabled
                    ? cs.onPrimary
                    : cs.onPrimary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: AppDimensions.iconSizeL,
              color: isEnabled
                  ? cs.onPrimary
                  : cs.onPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right panel with step navigation and active step highlighting.
class _InstructionsPanel extends StatefulWidget {
  final CookingModeViewModel vm;

  const _InstructionsPanel({required this.vm});

  @override
  State<_InstructionsPanel> createState() => _InstructionsPanelState();
}

class _InstructionsPanelState extends State<_InstructionsPanel> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _stepKeys;
  int _lastStepIndex = 0;

  CookingModeViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _stepKeys = List.generate(vm.instructions.length, (_) => GlobalKey());
    vm.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    vm.removeListener(_onViewModelChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    if (_lastStepIndex != vm.currentStepIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrentStep();
      });
    }
  }

  void _scrollToCurrentStep() {
    final index = vm.currentStepIndex;
    if (_lastStepIndex == index) return;
    _lastStepIndex = index;

    if (index < _stepKeys.length) {
      final stepContext = _stepKeys[index].currentContext;
      if (stepContext != null) {
        Scrollable.ensureVisible(
          stepContext,
          alignment: 0.3,
          duration: AppDimensions.animationDurationCommon,
          curve: Curves.easeInOut,
        );
      }
    }

    SemanticsService.announce(
      context.l10n.cookingModeStepAnnounce(
        index + 1,
        vm.instructions[index],
      ),
      TextDirection.ltr,
    );
  }

  /// BUT-406: Opens the step-timer bottom sheet. Duration is prefilled from
  /// the instruction text when a Swedish time phrase is detected; otherwise
  /// defaults to 5 minutes. The DI-registered [StepTimerService] is reused
  /// across openings so re-entry doesn't reset a running timer.
  void _openStepTimer(BuildContext context, String instruction) {
    final parsed = parseSwedishDuration(instruction);
    final duration = parsed ?? const Duration(minutes: 5);
    final service = ServiceLocator.get<StepTimerService>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) => StepTimerWidget(
        service: service,
        initialDuration: duration,
        sourcePhrase: parsed != null ? instruction : null,
        onExpired: () {
          HapticFeedback.mediumImpact();
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.timerExpired),
              backgroundColor: AppColors.starGold,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.primary.withValues(alpha: 0.8),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.spacingLg),
              itemCount: vm.instructions.length,
              itemBuilder: (context, index) {
                final instruction = vm.instructions[index];
                final stepNumber = index + 1;
                final isActive = index == vm.currentStepIndex;

                return KeyedSubtree(
                  key: _stepKeys[index],
                  child: Semantics(
                    label: context.l10n
                        .a11yCookingModeStep(stepNumber, instruction),
                    child: GestureDetector(
                      onTap: () => vm.goToStep(index),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppDimensions.spacingLg),
                        child: Opacity(
                          opacity: isActive ? 1.0 : 0.4,
                          child: Container(
                            decoration: isActive
                                ? BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: cs.surface,
                                        width: 3,
                                      ),
                                    ),
                                  )
                                : null,
                            padding: isActive
                                ? const EdgeInsets.only(
                                    left: AppDimensions.spacingSm)
                                : null,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: AppDimensions.minTouchTarget,
                                  height: AppDimensions.minTouchTarget,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? cs.surface
                                        : cs.surface.withValues(alpha: 0.6),
                                  ),
                                  child: Text(
                                    '$stepNumber',
                                    style: AppTextStyles.contentTitle.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize:
                                          AppTextStyles.contentTitle.fontSize! *
                                              vm.fontScale,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spacingMd),
                                Expanded(
                                  child: Semantics(
                                    label: context.l10n
                                        .a11yCookingStepLongPressTimer(
                                            stepNumber),
                                    button: true,
                                    child: GestureDetector(
                                      // BUT-406: long-press opens a step timer
                                      // sheet, pre-filled with the duration
                                      // parsed from this instruction (5 min
                                      // default fallback).
                                      onLongPress: () =>
                                          _openStepTimer(context, instruction),
                                      child: Text(
                                        instruction,
                                        style:
                                            AppTextStyles.titleLarge.copyWith(
                                          color: cs.onPrimary,
                                          height: 1.7,
                                          fontSize: AppTextStyles
                                                  .titleLarge.fontSize! *
                                              vm.fontScale,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _StepNavigation(vm: vm),
        ],
      ),
    );
  }
}

class _StepNavigation extends StatelessWidget {
  final CookingModeViewModel vm;

  const _StepNavigation({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      color: cs.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.arrow_back,
            label: context.l10n.cookingModePreviousStep,
            onPressed: vm.hasPreviousStep ? vm.previousStep : null,
          ),
          Text(
            context.l10n
                .cookingModeStepOf(vm.currentStepIndex + 1, vm.totalSteps),
            style: AppTextStyles.titleMedium.copyWith(color: cs.onPrimary),
          ),
          _NavButton(
            icon: Icons.arrow_forward,
            label: context.l10n.cookingModeNextStep,
            onPressed: vm.hasNextStep ? vm.nextStep : null,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return TappableWrapper(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      enabled: enabled,
      semanticLabel: label,
      child: Icon(
        icon,
        color: enabled
            ? cs.onPrimary
            : cs.onPrimary.withValues(alpha: AppDimensions.opacityLight),
        size: AppDimensions.iconSizeL,
      ),
    );
  }
}
