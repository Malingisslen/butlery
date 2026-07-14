// lib/views/cooking_mode_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/viewmodels/cooking/cooking_voice_controller.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';
import 'package:butlery/widgets/cooking/active_timers_strip.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';
import 'package:butlery/widgets/cooking/step_timer_widget.dart';
import 'package:butlery/widgets/cooking/voice_assist_button.dart';
import 'package:butlery/widgets/cooking/voice_heard_chip.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
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

  // Köksbutlern (tasks/koksbutlern-plan.md, Batch D): the voice layer's
  // state machine, scoped to this cooking session exactly like `_vm`.
  late final CookingVoiceController _voiceController;

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

    _voiceController = CookingVoiceController(
      voiceCapture: ServiceLocator.get<VoiceCaptureService>(),
      tts: ServiceLocator.get<TtsService>(),
      timers: ServiceLocator.get<StepTimerService>(),
      cookingVm: _vm,
    );
    // TtsService.init() is idempotent-safe (re-probes Swedish-voice
    // availability); the controller notifies when it resolves, so the
    // app-bar toggle reveals through its own ListenableBuilder — a
    // setState here couldn't reach it past the const content subtree.
    _voiceController.init();
  }

  @override
  void dispose() {
    // BUT-408: clear broadcast BEFORE disposing the VM. onExit() reads no
    // VM state, so the ordering is purely about signalling intent.
    _vm.onExit();
    // The voice controller reads the VM during teardown of an in-flight
    // capture — dispose it before the VM it depends on.
    _voiceController.dispose();
    _vm.dispose();
    // Restore all orientations and screen sleep
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CookingModeViewModel>.value(value: _vm),
        // ChangeNotifierProvider, NOT plain Provider: the controller is a
        // Listenable and provider's debug assert rejects it otherwise
        // (debugCheckInvalidValueType — crashes every debug build).
        ChangeNotifierProvider<CookingVoiceController>.value(
          value: _voiceController,
        ),
      ],
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
    final voiceController = context.watch<CookingVoiceController>();

    // A recipe with no steps would render a broken "Step 1 of 0" cooking UI —
    // show a clear empty state with a way out instead.
    if (vm.instructions.isEmpty) {
      return Scaffold(
        backgroundColor: cs.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.no_meals,
                    color: cs.onPrimary,
                    size: AppDimensions.iconSizeDisplay,
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  Text(
                    context.l10n.cookingModeNoInstructions,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  TextButton(
                    // Matches the top-bar close — cooking mode is always pushed.
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.commonClose,
                      style: TextStyle(color: cs.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // BUT-1360: cooking offline is the marquee scenario — surface a
            // slim top strip so the cook knows edits/substitutions won't sync.
            // Self-hides (SizedBox.shrink) when online, so the split layout is
            // untouched with a connection.
            LayoutComponents.offlineIndicator(),
            _buildTopBar(context, vm, voiceController),
            Expanded(
              child: Stack(
                children: [
                  Row(
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
                  // Köksbutlern (tasks/koksbutlern-plan.md): mic control +
                  // heard-chip overlay the instructions panel, bottom-right.
                  Positioned(
                    right: AppDimensions.spacingMd,
                    // Clear the _StepNavigation bar (~56 px row + padding):
                    // the next-step arrow lives in this exact corner and must
                    // stay tappable under the overlay (review finding #1).
                    bottom: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        VoiceHeardChip(controller: voiceController),
                        const SizedBox(height: AppDimensions.spacingXs),
                        VoiceAssistButton(
                          controller: voiceController,
                          onEnsurePermission: () =>
                              _ensureVoicePermission(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mic permission (rationale-first via [OsPermissionHelper]) + first-use
  /// model prepare, mirroring [VoicePromptButton]'s established flow.
  /// Returns false — quietly — on any denial or failure; the ordinary
  /// buttons keep working either way.
  Future<bool> _ensureVoicePermission(BuildContext context) async {
    final granted = await OsPermissionHelper.requestWithRationale(
      context: context,
      permission: Permission.microphone,
      rationaleTitle: context.l10n.voiceAssistMicRationaleTitle,
      // Generic body — the menu-specific one misstates purpose here.
      rationaleBody: context.l10n.voiceMicRationaleBody,
      grantLabel: context.l10n.voicePromptMicGrant,
      permanentlyDeniedMessage: context.l10n.voicePromptMicPermanentlyDenied,
      openSettingsLabel: context.l10n.voicePromptOpenSettings,
      gateway: const DefaultPermissionGateway(),
    );
    if (!granted || !context.mounted) return false;

    final modelReady = await ServiceLocator.get<VoiceCaptureService>()
        .prepareModel();
    if (!modelReady) {
      if (context.mounted) {
        // Cooking mode has no typed fallback — the bare string, without
        // the "typing works instead" pointer the text-field surfaces get.
        SnackBarUtils.showInfo(context, context.l10n.voiceAssistUnavailable);
      }
      return false;
    }
    return true;
  }

  Widget _buildTopBar(
    BuildContext context,
    CookingModeViewModel vm,
    CookingVoiceController voiceController,
  ) {
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
                // BUT-898: scale with the cooking-mode font-scale toggle
                // so the title matches step text + instruction body
                // (lines 560 + 586). WCAG 1.4.4 (Resize Text).
                fontSize: AppTextStyles.headerTitle.fontSize! * vm.fontScale,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildSpeakerToggle(context, voiceController),
          const SizedBox(width: AppDimensions.spacingXs),
          // Font size toggle
          ColoredBox(
            color: cs.surface,
            child: TappableWrapper(
              onTap: () => vm.cycleFontScale(),
              semanticLabel: context.l10n.a11yCookingModeFontScale,
              child: Text(
                'A${vm.fontScale == 1.0
                    ? ''
                    : vm.fontScale == 1.25
                    ? '+'
                    : '++'}',
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

  /// Mute toggle for the butler's readouts. Hidden entirely until
  /// [TtsService.init] confirms a Swedish voice is available — muting a
  /// voice that can never speak would be a dead control.
  Widget _buildSpeakerToggle(
    BuildContext context,
    CookingVoiceController voiceController,
  ) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: voiceController,
      builder: (context, _) {
        if (!voiceController.ttsAvailable) return const SizedBox.shrink();
        final muted = voiceController.muted;
        return IconButton(
          icon: Icon(
            muted ? Icons.volume_off : Icons.volume_up,
            color: cs.onPrimary,
          ),
          tooltip: muted
              ? context.l10n.voiceAssistUnmuteTooltip
              : context.l10n.voiceAssistMuteTooltip,
          onPressed: () => voiceController.muted = !muted,
        );
      },
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
              itemCount: vm.ingredientRows.length,
              itemBuilder: (context, index) {
                final row = vm.ingredientRows[index];
                // Component sub-heading ("Deg", "Fyllning") — a labelled
                // header, never long-pressable (headings aren't ingredients).
                if (row is IngredientHeadingRow) {
                  return Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.spacingMd,
                        bottom: AppDimensions.spacingTight,
                      ),
                      child: Text(
                        row.label.toUpperCase(),
                        style: AppTextStyles.titleSmall.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  );
                }
                final line = row as IngredientLineRow;
                return Semantics(
                  label: context.l10n.a11yCookingModeIngredient(line.text),
                  // BUT-202: long-press → substitution suggestions sheet.
                  // BUT-948 exception: long-press activates substitutions
                  // (feature affordance), not multi-select.
                  child: GestureDetector(
                    onLongPress: () => _showSubstitutionSheet(
                      context,
                      vm,
                      line.ingredientIndex,
                    ),
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
                              top: 8,
                              end: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cs.onPrimary,
                              shape: BoxShape.rectangle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.text,
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

    // BUT-1360: the lexicon lookup needs Firestore, so an empty result while
    // offline almost always means "couldn't reach the data" rather than "no
    // substitutes exist". Surface that explicitly. Only consulted when the list
    // is empty — cached suggestions still render normally offline.
    final isOffline =
        suggestions.isEmpty &&
        ServiceLocator.tryGet<ConnectivityMonitoringService>()
                ?.isConnectedToInternet ==
            false;

    if (!context.mounted) return;

    final chosen = await SubstitutionBottomSheet.show(
      context: context,
      ingredientName: ingredientLine,
      suggestions: suggestions,
      isOffline: isOffline,
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

    // Persisting the swap can fail (offline / Firestore error). Without
    // feedback the user believes the substitution was applied mid-cook when it
    // wasn't, so confirm success and surface failure for a retry.
    try {
      await recipeService.updateIngredient(
        vm.recipe.id,
        index,
        chosen.name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.cookingModeSubstitutionApplied),
        ),
      );
    } catch (e) {
      AppLogger.error('Cooking-mode ingredient substitution failed', e);
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.cookingModeSubstitutionFailed),
        ),
      );
    }
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

    SemanticsService.sendAnnouncement(
      View.of(context),
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
  void _openStepTimer(BuildContext context, int stepIndex, String instruction) {
    final parsed = parseSwedishDuration(instruction);
    final duration = parsed ?? const Duration(minutes: 5);
    final service = ServiceLocator.get<StepTimerService>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cs = Theme.of(context).colorScheme;
    final starGold = context.butleryColors.starGold;
    // BUT-1242: one timer per step so several can run at once.
    final timerId = 'step-$stepIndex';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) => StepTimerWidget(
        service: service,
        timerId: timerId,
        initialDuration: duration,
        sourcePhrase: parsed != null ? instruction : null,
        onExpired: () {
          HapticFeedback.mediumImpact();
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.timerExpired),
              backgroundColor: starGold,
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
          // BUT-1242: overview of all concurrently-running step timers.
          ActiveTimersStrip(
            service: ServiceLocator.get<StepTimerService>(),
            onTapTimer: (index) =>
                _openStepTimer(context, index, vm.instructions[index]),
          ),
          // BUT-1199: first-use hint for the long-press-step → timer gesture.
          SwipeHintBanner(
            seenKey: SwipeHintBanner.cookingStepSeenKey,
            icon: Icons.touch_app,
            message: context.l10n.cookingStepHintText,
          ),
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
                    label: context.l10n.a11yCookingModeStep(
                      stepNumber,
                      instruction,
                    ),
                    child: GestureDetector(
                      onTap: () => vm.goToStep(index),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.spacingLg,
                        ),
                        child: Opacity(
                          // 0.6 (was 0.4): inactive steps stay legible for the
                          // cook glancing at upcoming steps (WCAG contrast).
                          opacity: isActive ? 1.0 : 0.6,
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
                                ? const EdgeInsetsDirectional.only(
                                    start: AppDimensions.spacingSm,
                                  )
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
                                          stepNumber,
                                        ),
                                    button: true,
                                    child: GestureDetector(
                                      // BUT-406: long-press opens a step timer
                                      // sheet, pre-filled with the duration
                                      // parsed from this instruction (5 min
                                      // default fallback).
                                      // BUT-948 exception: long-press activates
                                      // the step timer (feature affordance),
                                      // not multi-select.
                                      onLongPress: () => _openStepTimer(
                                        context,
                                        index,
                                        instruction,
                                      ),
                                      // BUT-604: the duration phrase renders
                                      // as an inline tappable chip — visible
                                      // affordance for the same timer sheet.
                                      child: InlineTimerText(
                                        text: instruction,
                                        onTimerTap: (_) => _openStepTimer(
                                          context,
                                          index,
                                          instruction,
                                        ),
                                        chipColor: cs.onPrimary,
                                        style: AppTextStyles.titleLarge
                                            .copyWith(
                                              color: cs.onPrimary,
                                              height: 1.7,
                                              fontSize:
                                                  AppTextStyles
                                                      .titleLarge
                                                      .fontSize! *
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
            context.l10n.cookingModeStepOf(
              vm.currentStepIndex + 1,
              vm.totalSteps,
            ),
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
