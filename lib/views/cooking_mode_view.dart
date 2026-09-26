// lib/views/cooking_mode_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
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

/// How cooking mode was left, returned to the recipe detail view that
/// pushed it.
///
/// - [finished]: the user tapped "Klart" on the last step. The detail view
///   counts the recipe as cooked (flows-roles-budget.md:72).
/// - [editRecipe]: "Skriv stegen" from a recipe without steps.
/// - [toShoppingList]: "Till inköpslistan" from a recipe without steps
///   (produktregler.md:1227; Skarmar v12 etapp 11 #lgbutan).
enum CookingModeExit { finished, editRecipe, toShoppingList }

/// The device effects a cooking session has. Injectable so the session
/// rules can be proven without platform channels.
abstract class CookingSessionEffects {
  void lockLandscape();
  void releaseOrientation();
  void keepScreenAwake({required bool on});
  void edgeToEdge();
}

/// Production effects: SystemChrome and the wakelock.
class DefaultCookingSessionEffects implements CookingSessionEffects {
  const DefaultCookingSessionEffects();

  @override
  void lockLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void releaseOrientation() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void keepScreenAwake({required bool on}) {
    if (on) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void edgeToEdge() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

/// Rotation is forced only under 768 px on the shortest side; above that the
/// view follows the device (produktregler.md:1199).
const double cookingLandscapeLockBelow = 768;

/// True when a screen of [size] gets forced landscape in cooking mode.
bool cookingForcesLandscape(Size size) =>
    size.shortestSide < cookingLandscapeLockBelow;

/// The start and end of a cooking session, kept apart from the widget so the
/// rules are testable.
///
/// A recipe without steps is not a session: no forced rotation, no kept-awake
/// screen and no "lagar just nu" signal (produktregler.md:1227). The screen
/// is kept awake only while the view lives (produktregler.md:1201).
class CookingSessionLifecycle {
  CookingSessionLifecycle({required this.vm, required this.effects});

  final CookingModeViewModel vm;
  final CookingSessionEffects effects;

  bool _started = false;
  bool _active = false;
  bool _lockedOrientation = false;

  /// Starts the session once, for a screen of [screen] size.
  void start(Size screen) {
    if (_started) return;
    _started = true;
    if (!vm.hasSteps) return;
    _active = true;
    if (cookingForcesLandscape(screen)) {
      effects.lockLandscape();
      _lockedOrientation = true;
    }
    effects.keepScreenAwake(on: true);
    effects.edgeToEdge();
    // BUT-408: broadcast "lagar just nu" to friend groups. Fire-and-forget
    // — the VM swallows errors so a failed broadcast never blocks the cook.
    vm.onEnter();
  }

  /// Ends the session and gives the device back.
  void end() {
    if (!_active) return;
    _active = false;
    // BUT-408: clear the broadcast. onExit() reads no VM state that dispose
    // clears, so the ordering is about signalling intent.
    vm.onExit();
    if (_lockedOrientation) effects.releaseOrientation();
    effects.keepScreenAwake(on: false);
    effects.edgeToEdge();
  }
}

/// Asks before leaving once more than one step is done
/// (flows-roles-budget.md:71). Returns true when the user may leave.
Future<bool> confirmCookingExit(
  BuildContext context,
  CookingModeViewModel vm,
) async {
  if (!vm.needsExitConfirmation) return true;
  final l10n = context.l10n;
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cookingExitConfirmTitle),
      content: Text(
        l10n.cookingExitConfirmBody(vm.currentStepIndex + 1, vm.totalSteps),
      ),
      actions: [
        TextButton(
          key: const ValueKey('cooking-exit-stay'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cookingExitConfirmStay),
        ),
        TextButton(
          key: const ValueKey('cooking-exit-leave'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cookingExitConfirmLeave),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// Full-screen cooking mode with ingredients left, instructions right.
/// Keeps the screen awake while it lives, and forces landscape on screens
/// under 768 px (produktregler.md:1199-1201).
class CookingModeView extends StatefulWidget {
  final Recipe recipe;

  /// BUT-1613: members home for this meal when launched from a planned
  /// weekly-menu slot — opens cooking mode pre-scaled to who's home. Null for
  /// every other entry point (→ household default).
  final int? presentServings;

  /// Device effects; production uses [DefaultCookingSessionEffects].
  final CookingSessionEffects effects;

  const CookingModeView({
    super.key,
    required this.recipe,
    this.presentServings,
    this.effects = const DefaultCookingSessionEffects(),
  });

  @override
  State<CookingModeView> createState() => _CookingModeViewState();
}

class _CookingModeViewState extends State<CookingModeView> {
  // Hoisted out of build() so initState/dispose can wire the BUT-408
  // session broadcast lifecycle alongside wakelock/orientation setup.
  late final CookingModeViewModel _vm;
  late final CookingSessionLifecycle _lifecycle;

  // Köksbutlern (tasks/koksbutlern-plan.md, Batch D): the voice layer's
  // state machine, scoped to this cooking session exactly like `_vm`. Null
  // for a recipe without steps, which is not a cooking session.
  CookingVoiceController? _voiceController;

  // The timer notice is shown once per session: a notice repeated at every
  // timer has not accepted the answer (produktregler.md:1221-1224 spirit).
  bool _timerNoticeShown = false;

  @override
  void initState() {
    super.initState();
    _vm = CookingModeViewModel(
      recipe: widget.recipe,
      presentServings: widget.presentServings,
    );
    _lifecycle = CookingSessionLifecycle(vm: _vm, effects: widget.effects);
    if (!_vm.hasSteps) return;

    _voiceController = CookingVoiceController(
      voiceCapture: ServiceLocator.get<VoiceCaptureService>(),
      tts: ServiceLocator.get<TtsService>(),
      timers: ServiceLocator.get<StepTimerService>(),
      cookingVm: _vm,
      substitutions: ServiceLocator.get<SubstitutionSuggestionService>(),
      beforeTimerStart: _warnBeforeTimer,
    );
    // TtsService.init() is idempotent-safe (re-probes Swedish-voice
    // availability); the controller notifies when it resolves, so the
    // app-bar toggle reveals through its own ListenableBuilder — a
    // setState here couldn't reach it past the const content subtree.
    _voiceController!.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the screen size, so it runs here rather than in initState; the
    // lifecycle starts only once.
    _lifecycle.start(MediaQuery.sizeOf(context));
  }

  /// The notice before a timer starts without notification permission
  /// (P6-U07 mechanism; flows-roles-budget.md:70). Shared by the timer sheet
  /// and the voice command.
  Future<void> _warnBeforeTimer() async {
    if (_timerNoticeShown || !mounted) return;
    final service = ServiceLocator.tryGet<NotificationPermissionService>();
    if (service == null) return;
    final shown = await service.warnBeforeTimerIfNeeded(context);
    if (shown) _timerNoticeShown = true;
  }

  @override
  void dispose() {
    _lifecycle.end();
    // The voice controller reads the VM during teardown of an in-flight
    // capture — dispose it before the VM it depends on.
    _voiceController?.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A recipe with no steps would render a broken "Steg 1 av 0" cooking
    // UI — show the drawn empty state with a way on instead.
    final voiceController = _voiceController;
    if (!_vm.hasSteps || voiceController == null) {
      return CookingNoStepsState(
        hasIngredients: widget.recipe.ingredients.any(
          (line) => line.trim().isNotEmpty,
        ),
        onWriteSteps: () =>
            Navigator.of(context).pop(CookingModeExit.editRecipe),
        onToShoppingList: () =>
            Navigator.of(context).pop(CookingModeExit.toShoppingList),
        onClose: () => Navigator.of(context).pop(),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CookingModeViewModel>.value(value: _vm),
        // ChangeNotifierProvider, NOT plain Provider: the controller is a
        // Listenable and provider's debug assert rejects it otherwise
        // (debugCheckInvalidValueType — crashes every debug build).
        ChangeNotifierProvider<CookingVoiceController>.value(
          value: voiceController,
        ),
        Provider<CookingTimerGate?>.value(
          value: CookingTimerGate(_warnBeforeTimer),
        ),
      ],
      child: const _CookingModeContent(),
    );
  }
}

/// The notice gate the timer sheet awaits before it starts a timer.
class CookingTimerGate {
  const CookingTimerGate(this.beforeStart);

  final Future<void> Function() beforeStart;
}

/// A recipe without steps, as drawn in Skarmar v12 etapp 11 #lgbutan: a
/// title, a line saying what is missing, "Skriv stegen" and — when there are
/// ingredients — "Till inköpslistan" (produktregler.md:1227).
///
/// Colours on the cooking base (ink #24382C light / #17251D dark, paper text
/// on both): "Skriv stegen" is paper filled with ink text (cs.onPrimary /
/// cs.primary, the same in both modes), "Till inköpslistan" is outlined in
/// sage #93A48D (tokens.json:19, delivered as the dark text.disabled member
/// the step row already uses on this base) with paper text.
class CookingNoStepsState extends StatelessWidget {
  const CookingNoStepsState({
    super.key,
    required this.hasIngredients,
    required this.onWriteSteps,
    required this.onToShoppingList,
    required this.onClose,
  });

  final bool hasIngredients;
  final VoidCallback onWriteSteps;
  final VoidCallback onToShoppingList;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final sage = AppModeColors.textDisabled(Brightness.dark);
    return Scaffold(
      backgroundColor: _cookingBase(cs),
      body: FocusRingSurface(
        brightness: Brightness.dark,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingSm),
                  child: ColoredBox(
                    color: cs.onPrimary,
                    child: TappableWrapper(
                      onTap: onClose,
                      semanticLabel: l10n.a11yCookingModeClose,
                      child: Icon(
                        Icons.close,
                        color: cs.primary,
                        size: AppDimensions.iconSizeM,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.no_meals,
                            color: cs.onPrimary,
                            size: AppDimensions.iconSizeDisplay,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.cookingNoStepsTitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          hasIngredients
                              ? l10n.cookingNoStepsBody
                              : l10n.cookingNoStepsBodyNoIngredients,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingLg),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppDimensions.spacingSm,
                          runSpacing: AppDimensions.spacingSm,
                          children: [
                            FilledButton(
                              key: const ValueKey('cooking-no-steps-write'),
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.onPrimary,
                                foregroundColor: cs.primary,
                                minimumSize: const Size(
                                  AppDimensions.minTouchTarget,
                                  AppDimensions.minTouchTarget,
                                ),
                              ),
                              onPressed: onWriteSteps,
                              child: Text(l10n.cookingNoStepsWrite),
                            ),
                            if (hasIngredients)
                              OutlinedButton(
                                key: const ValueKey(
                                  'cooking-no-steps-shopping',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.onPrimary,
                                  side: BorderSide(color: sage, width: 1.5),
                                  minimumSize: const Size(
                                    AppDimensions.minTouchTarget,
                                    AppDimensions.minTouchTarget,
                                  ),
                                ),
                                onPressed: onToShoppingList,
                                child: Text(l10n.cookingNoStepsShopping),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

    // Cooking mode stands on surface.ink in light mode and on dark-bg
    // #17251D in dark mode (_cookingBase), so every focus ring in it is paper
    // (tokens.json:155-160; Komponentark v1:657).
    // Back and close ask first once more than one step is done
    // (flows-roles-budget.md:71); before that they leave at once.
    return PopScope<Object?>(
      canPop: !vm.needsExitConfirmation,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmCookingExit(context, vm)) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: _cookingBase(cs),
        body: FocusRingSurface(
          brightness: Brightness.dark,
          child: SafeArea(
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
                            color: cs.onPrimary.withValues(alpha: _onInkLine),
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
        color: _cookingBase(cs),
        border: Border(
          bottom: BorderSide(color: cs.onPrimary.withValues(alpha: _onInkLine)),
        ),
      ),
      child: Row(
        children: [
          // Recipe title
          Expanded(
            child: Text(
              vm.title,
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
          // Paper plates on ink: onPrimary is paper #F5F4ED in both
          // schemes, where surface would turn dark in dark mode and swallow
          // the ink glyph.
          ColoredBox(
            color: cs.onPrimary,
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
          // Mönster 4 · Modal (Komponentark v1:57, :91-97): cooking mode
          // closes with X and never shows a back arrow beside it.
          ColoredBox(
            color: cs.onPrimary,
            child: TappableWrapper(
              onTap: () => Navigator.maybePop(context),
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
      color: _cookingBase(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portion scaler controls
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              color: _cookingBase(cs),
              border: Border(
                bottom: BorderSide(
                  color: cs.onPrimary.withValues(alpha: _onInkLine),
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

    await persistCookingSubstitution(
      context,
      recipeService,
      recipeId: vm.recipe.id,
      index: index,
      name: chosen.name,
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
                color: isEnabled ? cs.onPrimary : _disabledOnInk,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: AppDimensions.iconSizeL,
              color: isEnabled ? cs.onPrimary : _disabledOnInk,
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
    // The notification notice comes before the timer starts (P6-U07).
    final gate = Provider.of<CookingTimerGate?>(context, listen: false);
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
        beforeStart: gate?.beforeStart,
        sourcePhrase: parsed != null ? instruction : null,
        onExpired: () {
          HapticFeedback.mediumImpact();
          // The ink snackbar, never a gold one (PQ-09 = A; Komponentark
          // v1:745-750). The messenger is captured before the sheet, so
          // this builds SnackBarUtils' content directly.
          messenger?.showSnackBar(
            SnackBar(
              content: InkSnackBar(message: l10n.timerExpired),
              padding: InkSnackBar.padding,
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
      color: _cookingBase(cs),
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
                                        color: cs.onPrimary,
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
                                  // As drawn in Skarmar v12 del 1 #laga: the
                                  // current step is a paper plate, the others
                                  // paper at 0.6, an allowed on-ink ladder
                                  // step (tokens.json:40-53 onInk). The digit
                                  // is the base colour on both, so it reads
                                  // on the 0.6 plate in dark mode too.
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? cs.onPrimary
                                        : cs.onPrimary.withValues(
                                            alpha: _onInkStepPlate,
                                          ),
                                  ),
                                  child: Text(
                                    '$stepNumber',
                                    style: AppTextStyles.contentTitle.copyWith(
                                      color: _cookingBase(cs),
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
          CookingStepNavigation(
            vm: vm,
            onFinish: () => Navigator.of(context).pop(CookingModeExit.finished),
          ),
        ],
      ),
    );
  }
}

/// The step row at the foot of the instructions: previous step, the step
/// counter and the view's one saffron action, "Nästa steg".
///
/// Public so its states can be proven without the whole view, which locks
/// the orientation and the screen in initState.
class CookingStepNavigation extends StatelessWidget {
  final CookingModeViewModel vm;

  /// "Klart" on the last step: returns to the recipe, which counts it as
  /// cooked (flows-roles-budget.md:72). Null keeps the last step's action
  /// disabled.
  final VoidCallback? onFinish;

  const CookingStepNavigation({required this.vm, this.onFinish, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // The view's one saffron action: "Nästa steg", or "Klart" on the last
    // step — one slot, one style.
    final heroStyle = ComponentThemes.heroButtonStyle(cs).copyWith(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppDimensions.minTouchTarget, AppDimensions.minTouchTarget),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      color: _cookingBase(cs),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.arrow_back,
            label: context.l10n.cookingModePreviousStep,
            onPressed: vm.hasPreviousStep ? vm.previousStep : null,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(
            context.l10n.cookingModeStepOf(
              vm.currentStepIndex + 1,
              vm.totalSteps,
            ),
            style: AppTextStyles.titleMedium.copyWith(color: cs.onPrimary),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          // The view's one saffron action (Komponentark v1 mönster 4;
          // Skarmar v12 del 1 'Matlagningsläge'; Grafisk manual v6:219).
          // It fills the rest of the row, as drawn (flex:1 in Skarmar v12
          // del 1 #lagastaende and #lagamorkt), with the arrow after the
          // label. The finite minimum keeps it layoutable inside a Row.
          Expanded(
            child: vm.isOnLastStep && onFinish != null
                ? FilledButton.icon(
                    key: const ValueKey('cooking-mode-finish'),
                    iconAlignment: IconAlignment.end,
                    style: heroStyle,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onFinish!();
                    },
                    icon: const Icon(Icons.check),
                    label: Text(context.l10n.cookingDone),
                  )
                : FilledButton.icon(
                    key: const ValueKey('cooking-mode-next-step'),
                    iconAlignment: IconAlignment.end,
                    style: heroStyle,
                    onPressed: vm.hasNextStep
                        ? () {
                            HapticFeedback.lightImpact();
                            vm.nextStep();
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(context.l10n.cookingModeNextStep),
                  ),
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
        color: enabled ? cs.onPrimary : _disabledOnInk,
        size: AppDimensions.iconSizeL,
      ),
    );
  }
}

/// Decorative lines on surface.ink: paper at the ladder's lowest on-ink
/// step (tokens.json:40-53 opacityLadder.onInk 0.18). A divider, never a
/// state.
const double _onInkLine = 0.18;

/// The cooking-mode base. Light mode: surface.ink #24382C (cs.primary).
/// Dark mode: dark-bg #17251D (cs.surface), "så skärmen inte lyser i ett
/// släckt kök" (Skarmar v12 del 1 #lagamorkt). Paper (cs.onPrimary) reads
/// on both.
Color _cookingBase(ColorScheme cs) =>
    cs.brightness == Brightness.dark ? cs.surface : cs.primary;

/// The plate behind a step number that is not current: paper at 0.6 on the
/// base, as drawn in Skarmar v12 del 1 #laga (tokens.json:40-53 onInk).
const double _onInkStepPlate = 0.6;

/// A disabled control on the cooking-mode base, in both modes: #93A48D, the
/// dark text.disabled.onRaised (tokens.json:198-201), never paper at an
/// opacity. It measures 4.73:1 on ink #24382C (light base) and 5.9:1 on
/// #17251D (dark base), above the 4.5:1 the P4-U06 test plan asks for and the
/// 3:1 disabled floor (tokens.json contrastPolicy).
final Color _disabledOnInk = AppModeColors.textDisabled(Brightness.dark);

/// Persisting the swap can fail (offline / Firestore error). Without
/// feedback the user believes the substitution was applied mid-cook when it
/// wasn't, so confirm success and surface failure for a retry.
///
/// P5-U09: the failure is the three-part failure snackbar
/// (content-style-guide.md:87-97): the swap was not saved, the recipe is
/// unchanged, and Försök igen saves the same swap again. The service reports
/// most failures by returning false rather than throwing
/// (personal_recipe_module.dart, realtime_ingredient_operations.dart), so
/// false is a failure too.
@visibleForTesting
Future<void> persistCookingSubstitution(
  BuildContext context,
  UnifiedRecipeService recipeService, {
  required String recipeId,
  required int index,
  required String name,
}) async {
  var saved = false;
  try {
    saved = await recipeService.updateIngredient(recipeId, index, name);
  } catch (e) {
    AppLogger.error('Cooking-mode ingredient substitution failed', e);
  }
  if (!context.mounted) return;
  // A failure stays until tapped; the new outcome replaces it rather than
  // queueing behind it, so a later success is not hidden by a stale error.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  if (saved) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.cookingModeSubstitutionApplied),
      ),
    );
    return;
  }
  SnackBarUtils.showFailure(
    context,
    what: context.l10n.cookingModeSubstitutionFailed,
    preserved: context.l10n.cookingModeRecipeUnchanged,
    action: FailureAction.retry(
      () => persistCookingSubstitution(
        context,
        recipeService,
        recipeId: recipeId,
        index: index,
        name: name,
      ),
    ),
  );
}
