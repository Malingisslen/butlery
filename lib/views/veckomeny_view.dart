/// Weekly menu planning view with filter-based generation and social sharing.
library;

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart'
    show PlacementSaveResult;
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/menu/menu_placement_footer.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';
import 'package:butlery/widgets/menu/veckomeny_planning_cancel_footer.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:butlery/widgets/realtime/conflict_snackbar.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart'
    show VeckomenyDialogs;
import 'package:butlery/widgets/voice/voice_prompt_button.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Weekly menu planning view with natural language input and social sharing.
/// The week menu's root-bar overflow actions.
enum _VeckomenyRootAction { load, save, clear }

class VeckomenyView extends StatelessWidget {
  final SharedMenu? sharedMenu;

  /// Opens the shared menu with this `realtime_resources` id live.
  final String? realtimeMenuId;

  const VeckomenyView({super.key, this.sharedMenu, this.realtimeMenuId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MenuViewModel()),
        ChangeNotifierProvider(
          create: (_) => ServiceLocator.get<WeeklyMenuPlanViewModel>(),
        ),
      ],
      child: _VeckomenyViewContent(
        sharedMenu: sharedMenu,
        realtimeMenuId: realtimeMenuId,
      ),
    );
  }
}

class _VeckomenyViewContent extends StatefulWidget {
  final SharedMenu? sharedMenu;
  final String? realtimeMenuId;

  const _VeckomenyViewContent({this.sharedMenu, this.realtimeMenuId});

  @override
  State<_VeckomenyViewContent> createState() => _VeckomenyViewContentState();
}

class _VeckomenyViewContentState extends State<_VeckomenyViewContent> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final UnifiedFriendsService _friendsService =
      ServiceLocator.get<UnifiedFriendsService>();

  VeckomenyViewMode _viewMode = VeckomenyViewMode.lista;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _loadViewModePreference();

    if (widget.realtimeMenuId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          context.read<MenuViewModel>().startLiveMenu(widget.realtimeMenuId!),
        );
      });
    } else if (widget.sharedMenu != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MenuViewModel>().loadFromSharedMenu(widget.sharedMenu!);
      });
    }
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadViewModePreference() async {
    final stored = await ServiceLocator.get<PersistenceService>()
        .getVeckomenyViewMode();
    if (!mounted) return;
    // A live menu stays in Lista: its dishes are not placed in the user's own
    // week, so the calendar and the week's shopping source do not apply.
    if (widget.realtimeMenuId != null) {
      await context.read<WeeklyMenuPlanViewModel>().loadWeek(clock.now());
      return;
    }
    if (stored != null) {
      final mode = VeckomenyViewMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => VeckomenyViewMode.lista,
      );
      if (mode != _viewMode) setState(() => _viewMode = mode);
      // Kalender reads the week itself; Lista needs it for the week line.
      if (mode != VeckomenyViewMode.kalender) {
        await context.read<WeeklyMenuPlanViewModel>().loadWeek(clock.now());
      }
      return;
    }
    // First run (no stored preference): the saved weekly plan only renders in
    // kalender mode, so defaulting to lista would show a first-time user an
    // empty prompt screen even though a plan exists. Peek at the current
    // week and open in kalender when it already has entries — otherwise stay
    // in lista (the generate-a-menu entry point). This is a transient
    // first-open default, so it is deliberately NOT persisted.
    final planVm = context.read<WeeklyMenuPlanViewModel>();
    await planVm.loadWeek(clock.now());
    if (!mounted) return;
    if (planVm.hasEntries && _viewMode != VeckomenyViewMode.kalender) {
      setState(() => _viewMode = VeckomenyViewMode.kalender);
    }
  }

  /// BUT-1241: the toggle is a pure view switch now. The old silent
  /// distribute-on-toggle bridge was replaced by the explicit choice footer
  /// in lista mode (auto vs manual placement).
  Future<void> _setViewMode(VeckomenyViewMode mode) async {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    await ServiceLocator.get<PersistenceService>().setVeckomenyViewMode(
      mode.name,
    );
  }

  Future<void> _generateMenu() async {
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();

    // P6-U01: offline, generation is switched off (produktregler.md:1131).
    // The button is already off with its reason; this keeps a stale tap from
    // starting anything.
    if (!VeckomenyConnectivity.isOnlineNow()) return;

    // If we're in calendar mode and the visible week already has entries,
    // confirm before overwriting.
    if (_viewMode == VeckomenyViewMode.kalender && calendarVm.hasEntries) {
      final confirmed = await _confirmOverwrite();
      if (!confirmed || !mounted) return;
    }

    // BUT-1611: presence (who's home per meal) drives DISPLAY, portions and
    // the who's-eating record — it deliberately does NOT scope the generation
    // pool. Narrowing the pool to present diners would filter allergens below
    // the whole-household baseline (övrigt is eaten by everyone; a single
    // re-roll would reuse a stale set), so generation always keeps the safe
    // household-aggregated filtering (BUT-1464). Safe present-aware generation
    // is a follow-up (BUT-1625).
    // BUT-2157: a cancelled run places nothing, so the week stays as it was.
    final end = await menuVm.generateMenu(_promptController.text);
    if (!mounted || end != MenuGenerationEnd.completed) return;

    // P6-U01: "Inga recept matchar" is drawn in Lista (Skarmar v12 del 1
    // #veckoingamatch), so a calendar-mode generation that matched nothing
    // goes there to say so. The week is untouched.
    if (_viewMode == VeckomenyViewMode.kalender &&
        menuVm.noMatchOutcome != null) {
      await _setViewMode(VeckomenyViewMode.lista);
      return;
    }

    // P6-U01: offline during generation. The flow's "avbrutet, tidigare
    // vecka orörd" (flows-roles-budget.md:34): nothing is placed, the saved
    // week stays as it was, and the suggestion waits in Lista.
    if (_viewMode == VeckomenyViewMode.kalender &&
        menuVm.hasMenu &&
        !VeckomenyConnectivity.isOnlineNow()) {
      await _setViewMode(VeckomenyViewMode.lista);
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        context.l10n.menuGenerateOfflineStopped,
        showCloseButton: true,
      );
      return;
    }

    if (_viewMode == VeckomenyViewMode.kalender && menuVm.hasMenu) {
      // Overwrite was already confirmed above.
      //
      // BUT-2129: announced at the publish, not at the ack. Reading the return
      // value left this path silent offline — the save never acks, so the
      // confirmation never arrived over a week the user could already see.
      await _applyGeneratedToCalendar(
        skipConfirm: true,
        onPublished: (placed) {
          // BUT-2157: once the suggestion is in the week it is no longer a
          // draft.
          unawaited(menuVm.markDraftSaved());
          if (!mounted) return;
          if (placed > 0) _showAutoPlacedToast(placed);
        },
      );
    }
  }

  /// BUT-2157: "Avbryt planeringen" puts the earlier screen back and hands
  /// focus to the prompt, the way on from there.
  void _cancelPlanning() {
    context.read<MenuViewModel>().cancelGeneration();
    // The prompt is switched off while planning; it takes focus once the
    // rebuild has switched it on again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _promptFocusNode.requestFocus();
    });
  }

  /// BUT-1241: auto-distribute the generated menu onto the CURRENT week —
  /// the same week the calendar opens on, and the only week where the
  /// today-anchored distribution semantics ("inga recept på passerade
  /// dagar") make sense. Confirms overwrite when the week already has
  /// entries, threads the parsed day pins, and surfaces failures here
  /// (lista mode never renders the calendar VM's error state). Returns the
  /// placed count, or null when cancelled / failed / nothing to place.
  Future<int?> _applyGeneratedToCalendar({
    bool skipConfirm = false,
    void Function(int placed)? onPublished,
  }) async {
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();
    if (!menuVm.hasMenu) return null;
    await calendarVm.loadWeek(clock.now());
    if (!mounted) return null;
    if (!skipConfirm && calendarVm.hasEntries) {
      final confirmed = await _confirmOverwrite();
      if (!confirmed || !mounted) return null;
    }
    final parsed = await menuVm.parsedRequestForLastPrompt();
    if (!mounted) return null;
    final placed = await calendarVm.applyGeneratedMenu(
      menuVm.menu,
      replaceExisting: true,
      parsedRequest: parsed,
      onPublished: onPublished,
    );
    if (placed == null && mounted) {
      final error = calendarVm.error;
      if (error != null) {
        showWeekPlacementFailure(
          context,
          what: error,
          weekUnchanged: calendarVm.lastApplyLeftWeekUnchanged,
          // The retry asks again whenever the week holds entries. The first
          // confirmation covered the week as it was then; by now the user may
          // have changed it (the rollback is skipped when they moved on), or
          // an empty week may have been filled. Overwriting always asks
          // (content-style-guide.md, "Behåll min vecka / Skriv över").
          onRetry: () => unawaited(
            _applyGeneratedToCalendar(onPublished: onPublished),
          ),
        );
      }
    }
    return placed;
  }

  /// Footer primary action: auto-place, switch to kalender, offer ÄNDRA.
  ///
  /// BUT-2124: both happen at PUBLISH, not at the save's ack. Offline the ack
  /// never comes, so the old order left the user in list mode watching a
  /// spinner while the week sat finished underneath it.
  Future<void> _onPlaceAutomatically() async {
    final menuVm = context.read<MenuViewModel>();
    await _applyGeneratedToCalendar(
      onPublished: (placed) {
        unawaited(menuVm.markDraftSaved());
        if (!mounted) return;
        unawaited(_setViewMode(VeckomenyViewMode.kalender));
        // placed == 0 (everything overflowed) skips the toast — the calendar's
        // overflow tray explains the outcome better than a "0 placed" snackbar.
        if (placed > 0) _showAutoPlacedToast(placed);
      },
    );
  }

  void _showAutoPlacedToast(int placed) {
    UndoSnackBar.capture(context).showReceipt(
      context.l10n.menuAutoPlacedToast(placed),
      actionLabel: context.l10n.menuAutoPlacedChangeAction,
      onAction: () => unawaited(_openPlacement(redoAuto: true)),
    );
  }

  /// Opens the manual placement mode (BUT-1241). [redoAuto] is the ÄNDRA
  /// path: the working week starts empty because the saved plan holds the
  /// auto layout being redone (same replace semantics the auto path used).
  Future<void> _openPlacement({required bool redoAuto}) async {
    if (!mounted) return;
    final menuVm = context.read<MenuViewModel>();
    final calendarVm = context.read<WeeklyMenuPlanViewModel>();
    if (!menuVm.hasMenu) return;
    final parsed = await menuVm.parsedRequestForLastPrompt();
    if (!mounted) return;
    final result = await Navigator.of(context).push<PlacementSaveResult>(
      MaterialPageRoute(
        builder: (_) => MenuPlacementView(
          generated: menuVm.menu,
          weekStart: calendarVm.currentWeekStart,
          parsedRequest: parsed,
          startFromEmptyWeek: redoAuto,
        ),
      ),
    );
    if (result == null || !mounted) return;
    unawaited(menuVm.markDraftSaved());
    // Adopt the just-persisted plan instead of re-reading it from
    // Firestore; the session ids give manual placements the same NY-badge
    // treatment as auto-distribution.
    calendarVm.adoptPlan(
      result.plan,
      recentlyPlacedEntryIds: result.sessionEntryIds,
    );
    await _setViewMode(VeckomenyViewMode.kalender);
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      context.l10n.menuPlacementSaved(result.placed),
    );
  }

  Future<bool> _confirmOverwrite() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.weeklyMenuOverwriteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonContinue),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _clearMenu() {
    context.read<MenuViewModel>().clearMenu();
    _promptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();

    // The root bar (Komponentark v1:60-68; Skarmar v12 del 1 #veckomeny,
    // #tomvecka): "Veckomeny" with the week and the number of dishes on the
    // line under it, and the Lista/Kalender tabs under the bar.
    //
    // P5-U26a: the week menu listens for "{namn} sparade veckan", and
    // BUT-2215 for its own week saved on another device.
    final planVm = context.watch<WeeklyMenuPlanViewModel>();
    return VeckomenyConflictNotice(
      weekConflicts: planVm.weekConflicts,
      onKeepMine: planVm.keepMine,
      child: _buildScaffold(context, viewModel, planVm),
    );
  }

  /// The week line counts the SAVED week, never the generated suggestion: a
  /// suggestion is not planned until it is placed, and a week saved on
  /// another device or in an earlier session has no suggestion at all.
  String _weekLine(BuildContext context, WeeklyMenuPlanViewModel planVm) {
    final week = IsoWeekUtils.isoWeekNumber(planVm.currentWeekStart);
    final dishes = planVm.plannedDishCount;
    if (dishes == null) return context.l10n.menuWeekBadgeOnly(week);
    if (dishes == 0) return context.l10n.menuWeekBadgeEmpty(week);
    return context.l10n.menuWeekBadgeWithCount(week, dishes);
  }

  Widget _buildScaffold(
    BuildContext context,
    MenuViewModel viewModel,
    WeeklyMenuPlanViewModel planVm,
  ) {
    return Scaffold(
      appBar: ButleryTopBar.rot(
        title: context.l10n.menuWeek,
        secondaryLine: _weekLine(context, planVm),
        actions: _buildHeaderActions(context, viewModel),
        // A live menu has no calendar placement, so only the list is shown.
        bottom: widget.realtimeMenuId == null
            ? VeckomenyViewModeToggle(
                mode: _viewMode,
                onSelect: (mode) => unawaited(_setViewMode(mode)),
              )
            : null,
      ),
      body: _buildBody(context, viewModel),
      floatingActionButton: _buildShoppingFab(context, viewModel),
      // BUT-2275: in the Scaffold's bottom slot the shopping button floats
      // above the footer; inside the body it covered "Jag placerar själv".
      bottomNavigationBar: _buildPlacementFooter(context, viewModel),
    );
  }

  /// BUT-1241: explicit placement choice for the generated result.
  Widget? _buildPlacementFooter(BuildContext context, MenuViewModel viewModel) {
    if (_viewMode != VeckomenyViewMode.lista ||
        widget.realtimeMenuId != null ||
        !viewModel.hasMenu ||
        viewModel.isGenerating ||
        viewModel.hasError ||
        // BUT-2275: the Scaffold lifts the body over the keyboard but not
        // this slot, so the buttons would sit unreachable under it.
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return null;
    }
    return MenuPlacementChoiceFooter(
      // BUT-1987: the placement state lives on the CALENDAR viewmodel, which
      // owns the write.
      isPlacing: context
          .watch<WeeklyMenuPlanViewModel>()
          .isPlacingGeneratedMenu,
      onPlaceAuto: () => unawaited(_onPlaceAutomatically()),
      onPlaceManual: () => unawaited(_openPlacement(redoAuto: false)),
    );
  }

  /// P6-U02: "Till inköpslistan" opens the merge sheet from both view modes,
  /// "enda vägen från veckomeny till lista" (Skarmar v12 del 2 #inkopmerge;
  /// flows-roles-budget.md:46). Calendar mode merges the visible week's
  /// plan; list mode merges the generated menu into the current week's list.
  Widget? _buildShoppingFab(BuildContext context, MenuViewModel viewModel) {
    final planVm = context.watch<WeeklyMenuPlanViewModel>();
    final hasSource = _viewMode == VeckomenyViewMode.kalender
        ? planVm.hasEntries
        : viewModel.hasMenu;
    if (!hasSource) return null;
    return ActionButtons.actionButton(
      context,
      label: context.l10n.menuToShoppingList,
      icon: ButleryIcons.shoppingCart,
      isLoading: planVm.isShoppingFlowRunning,
      onPressed: () => unawaited(_openShoppingMerge()),
      style: ActionButtonStyle.primary,
    );
  }

  /// P6-U02: flow 02. Three outcomes stay apart (produktregler.md:705):
  /// nothing to generate (a warning), failed (what happened, what is kept,
  /// Försök igen) and already running (silence). A confirmed merge opens the
  /// list and offers Ångra for 7 s (produktregler.md:131, § 2.4).
  ///
  /// One flow at a time, from the tap until the sheet has closed and the
  /// write has finished (WeeklyMenuPlanViewModel.runShoppingFlow): a second
  /// tap during the week or pantry read opens no second sheet.
  Future<void> _openShoppingMerge() => context
      .read<WeeklyMenuPlanViewModel>()
      .runShoppingFlow(_runShoppingMerge);

  Future<void> _runShoppingMerge() async {
    final planVm = context.read<WeeklyMenuPlanViewModel>();
    final menuVm = context.read<MenuViewModel>();
    final source = _viewMode == VeckomenyViewMode.kalender
        ? await planVm.shoppingSource()
        : MenuShoppingListGenerator.sourceForMenu(menuVm.menu, clock.now());
    if (!mounted) return;
    if (source == null) {
      showWeekShoppingListFailure(
        context,
        onRetry: () => unawaited(_openShoppingMerge()),
      );
      return;
    }
    if (source.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        context.l10n.menuShoppingListGenerationEmpty,
      );
      return;
    }
    final pantry = await planVm.readPantryForShopping();
    if (!mounted) return;
    final merge = await showShoppingMergeSheet(
      context,
      source: source,
      pantry: pantry,
      retryPantry: planVm.readPantryForShopping,
      canReplace: planVm.canReplaceShoppingList(source.week),
    );
    if (merge == null || !mounted) return;
    final receipt = await planVm.applyShoppingMerge(merge);
    if (!mounted) return;
    if (identical(receipt, shoppingMergeAlreadyRunning)) return;
    if (receipt == null) {
      showWeekShoppingListFailure(
        context,
        onRetry: () => unawaited(_openShoppingMerge()),
      );
      return;
    }
    // The list itself is the confirmation (BUT-900); the receipt rides on
    // the root messenger above it. SnackbarRouteObserver clears snackbars on
    // every push, so the receipt is shown after the push.
    unawaited(Navigator.pushNamed(context, Routes.shoppingList));
    showShoppingMergeReceipt(
      context,
      receipt,
      onUndo: () => unawaited(_undoShoppingMerge(planVm, receipt)),
    );
  }

  /// Ångra failed: says so, and that the rows are still on the list
  /// (content-style-guide.md:87-97).
  Future<void> _undoShoppingMerge(
    WeeklyMenuPlanViewModel planVm,
    MenuShoppingMergeReceipt receipt,
  ) async {
    final undone = await planVm.undoShoppingMerge(receipt);
    if (undone || !mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.shoppingMergeUndoFailed,
      preserved: context.l10n.shoppingMergeUndoFailedKept,
    );
  }

  List<Widget> _buildHeaderActions(
    BuildContext context,
    MenuViewModel viewModel,
  ) {
    // The bar gives the icons its own foreground: text.primary on the light
    // root bar in both modes (ButleryTopBar).
    //
    // Skarmar v12 del 1 #veckomeny draws no icons on the root bar, and four
    // 48 dp icons would leave "Veckomeny" too little width on a 320 dp
    // phone. The group week keeps its icon (it is reached from here and from
    // the group chat, BUT-1971); load, save and clear share one overflow
    // menu, so the title always has room.
    return [
      const GroupMenuEntryButton(),
      PressFill(
        surface: PressSurface.base,
        child: PopupMenuButton<_VeckomenyRootAction>(
          key: const ValueKey('veckomeny-root-more'),
          icon: const ButleryIcon(ButleryIcons.moreVertical),
          tooltip: context.l10n.rootBarMoreActions,
          onSelected: (action) {
            switch (action) {
              case _VeckomenyRootAction.load:
                unawaited(
                  VeckomenyDialogs.showLoadMenuBottomSheet(
                    context,
                    viewModel: viewModel,
                    onTemplateSelected: (prompt) {
                      _promptController.text = prompt;
                      setState(() {});
                    },
                  ),
                );
              case _VeckomenyRootAction.save:
                unawaited(
                  VeckomenyDialogs.showSaveMenuDialog(
                    context,
                    viewModel: viewModel,
                    availableFriends: _friendsService.friends,
                  ),
                );
              case _VeckomenyRootAction.clear:
                _clearMenu();
            }
          },
          itemBuilder: (menuContext) => [
            // Loading a saved menu would replace the shared one on screen.
            if (widget.realtimeMenuId == null)
              _rootItem(
                _VeckomenyRootAction.load,
                ButleryIcons.folder,
                context.l10n.menuLoadSaved,
              ),
            if (viewModel.hasMenu)
              _rootItem(
                _VeckomenyRootAction.save,
                ButleryIcons.save,
                context.l10n.menuSave,
              ),
            // A clear would empty the menu for everyone it is shared with.
            if (viewModel.hasMenu && widget.realtimeMenuId == null)
              _rootItem(
                _VeckomenyRootAction.clear,
                ButleryIcons.x,
                context.l10n.menuClear,
              ),
          ],
        ),
      ),
    ];
  }

  /// One overflow row; icon and text take the menu's foreground (onSurface,
  /// text.primary in both modes).
  ButleryMenuItem<_VeckomenyRootAction> _rootItem(
    _VeckomenyRootAction value,
    IconData icon,
    String label,
  ) {
    return ButleryMenuItem<_VeckomenyRootAction>(
      key: ValueKey('veckomeny-root-${value.name}'),
      value: value,
      child: Row(
        children: [
          ButleryIcon(icon, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingM),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  /// The view's one saffron action, switched off offline with the reason
  /// in text (P6-U01, [VeckomenyGenerateButton]).
  Widget _buildGenerateButton(BuildContext context, MenuViewModel viewModel) {
    final hasPrompt = _promptController.text.isNotEmpty;
    return Center(
      key: const ValueKey('test-veckomeny-generate'),
      child: VeckomenyGenerateButton(
        label: viewModel.hasMenu
            ? context.l10n.menuGenerateNew
            : context.l10n.menuGenerate,
        busy: viewModel.isGenerating,
        busyLabel: context.l10n.weekMenuPlanningTitle,
        onGenerate: hasPrompt ? () => unawaited(_generateMenu()) : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context, MenuViewModel viewModel) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 900,
            desktop: 1200,
          ),
        ),
        child: Column(
          children: [
            LayoutComponents.offlineIndicator(),
            // BUT-407: online-members presence bar (union across groups).
            const FamilyPresenceBar(),
            // BUT-408: live cooking session card for the user's groups.
            const VeckomenyCookingSessionCard(),
            // A new generation would overwrite the menu for everyone.
            if (widget.realtimeMenuId == null)
              Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: Column(
                  children: [
                    MenuContentWidgets.buildPromptInput(
                      context,
                      controller: _promptController,
                      focusNode: _promptFocusNode,
                      isGenerating: viewModel.isGenerating,
                      onClear: () {
                        _promptController.clear();
                        setState(() {});
                      },
                      onChanged: () => setState(() {}),
                      // Voice prompt (kb-whisper plan): transcript lands
                      // EDITABLE here — the user reviews before generating.
                      voiceButton: VoicePromptButton(
                        enabled: !viewModel.isGenerating,
                        onTranscript: (text) {
                          _promptController.text = text;
                          _promptController.selection = TextSelection.collapsed(
                            offset: text.length,
                          );
                          _promptFocusNode.requestFocus();
                          setState(() {});
                        },
                      ),
                    ),
                    SizedBox(
                      height: LayoutComponents.valueFor(
                        context: context,
                        mobile: AppDimensions.spacingL,
                        tablet: AppDimensions.spacingXl,
                        desktop: AppDimensions.spacingXl,
                      ),
                    ),
                    _buildGenerateButton(context, viewModel),
                    SizedBox(
                      height: LayoutComponents.valueFor(
                        context: context,
                        mobile: AppDimensions.spacingXl,
                        tablet: AppDimensions.spacingXl * 1.5,
                        desktop: AppDimensions.spacingXxl,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.realtimeMenuId case final id?)
              ConflictBanner(filterDocId: id),
            Expanded(
              child: Padding(
                padding: AppDimensions.responsiveHorizontalPadding(context),
                child: viewModel.isGenerating
                    // The week while it is planned: the plate line with
                    // text in the content area, never an overlay over the
                    // view (Skarmar v12 del 1 #veckogenererarpanel;
                    // ux-beslut.json D-03).
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const VeckomenyGeneratingOverlay(),
                            const SizedBox(height: AppDimensions.spacingMd),
                            VeckomenyPlanningCancelFooter(
                              onCancel: _cancelPlanning,
                            ),
                          ],
                        ),
                      )
                    : _viewMode == VeckomenyViewMode.kalender &&
                          widget.realtimeMenuId == null
                    ? SingleChildScrollView(
                        // BUT-1611: per-meal "who's home" lives inside the
                        // calendar (faces on each slot + a collapsible
                        // week overview), not a separate strip.
                        child: CalendarWeeklyMenuWidget(
                          onRefinePrompt: _promptFocusNode.requestFocus,
                        ),
                      )
                    : Column(
                        children: [
                          // P5-U25: fewer dishes than asked is a partial
                          // outcome, named above the list.
                          if (viewModel.partialOutcome != null &&
                              !viewModel.hasError)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingSm,
                              ),
                              child: VeckomenyPartialResult(
                                outcome: viewModel.partialOutcome!,
                              ),
                            ),
                          Expanded(
                            child:
                                viewModel.noMatchOutcome != null &&
                                    !viewModel.hasError
                                // P6-U01: nothing matched is its own
                                // outcome, never "Ett fel uppstod".
                                ? VeckomenyNoMatch(
                                    outcome: viewModel.noMatchOutcome!,
                                    onEditPrompt: _promptFocusNode.requestFocus,
                                    onPlanYourself: () => unawaited(
                                      _setViewMode(VeckomenyViewMode.kalender),
                                    ),
                                  )
                                : MenuContentWidgets.buildMenuContent(
                                    context,
                                    viewModel: viewModel,
                                    votingViewModel: viewModel.votingViewModel,
                                    onRetry: _promptController.text.isNotEmpty
                                        ? () => unawaited(_generateMenu())
                                        : null,
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P5-U25: a generation that found fewer dishes than were asked for
/// (produktregler.md:206: "1 ≤ n < begärt antal recept"). It says "Vi hittade
/// n av m rätter" and names each meal type that is short (produktregler.md:
/// 893: "Ett antal utan namn är ingen upplysning"), in the shared I-29 form
/// (produktregler.md:905-909). Instead of looking complete, the result says
/// what it is. The way on is the view's own Generera, which stays.
class VeckomenyPartialResult extends StatelessWidget {
  const VeckomenyPartialResult({super.key, required this.outcome});

  final MenuPartialOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PartialOutcome(
      title: l.menuPartialTitle(outcome.found, outcome.requested),
      message: l.menuPartialBody,
      items: [
        for (final meal in outcome.missing)
          PartialOutcomeItem(
            id: 'meal-${meal.mealType}',
            label: MenuViewHelpers.capitalizeCategory(meal.mealType),
            reason: l.menuPartialMissing(
              meal.found,
              meal.requested,
              meal.missing,
            ),
          ),
      ],
    );
  }
}

/// P6-U01: a generation where nothing matched (flows-roles-budget.md:32;
/// fas2/block288-uxfrysning.json TR::FLOW::01::genererar::0-recept-placerade
/// REQUIRED).
///
/// Skarmar v12 del 1 #veckoingamatch: "Nollresultat säger vad som stoppade
/// det och erbjuder minsta möjliga eftergift — inte en generisk feltext.
/// Illustration, inte felikon: ingenting har gått sönder." The title "Inga
/// recept matchar", a line with the size of the library, the requirements
/// the prompt was read as, and two ways on.
///
/// Interpretations, recorded: the drawing's "Släpp ett krav" chips and its
/// "Planera utan tidsgräns" rewrite the prompt, which nothing in the app can
/// do yet, so the requirements are named as text and "Ändra beskrivningen"
/// moves focus to the prompt. "Lägg dagarna själv" opens the calendar. Both
/// are outlined, because the view's one saffron action is Generera
/// (Komponentark v1:843-844). The app has no cookbook illustration, so the
/// empty state's no-search-results illustration stands in.
class VeckomenyNoMatch extends StatelessWidget {
  const VeckomenyNoMatch({
    super.key,
    required this.outcome,
    required this.onEditPrompt,
    required this.onPlanYourself,
  });

  final MenuNoMatchOutcome outcome;
  final VoidCallback onEditPrompt;
  final VoidCallback onPlanYourself;

  static const Key editPromptKey = ValueKey<String>('veckomeny-nomatch-edit');
  static const Key planYourselfKey = ValueKey<String>(
    'veckomeny-nomatch-plan',
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noSearchResults,
      title: l.menuNoMatchTitle,
      subtitle: l.menuNoMatchBody(outcome.poolSize),
      customAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (outcome.constraints.isNotEmpty) ...[
            Text(
              l.menuNoMatchConstraints(outcome.constraints.join(', ')),
              textAlign: TextAlign.center,
              // text.secondary in both modes (onSurfaceVariant).
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
          OutlinedButton(
            key: editPromptKey,
            onPressed: onEditPrompt,
            child: Text(l.menuNoMatchEditPrompt),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          OutlinedButton(
            key: planYourselfKey,
            onPressed: onPlanYourself,
            child: Text(l.menuNoMatchPlanYourself),
          ),
        ],
      ),
    );
  }
}

/// P5-U26a: mounts P3-U08's week conflict snackbar on the week menu.
///
/// produktregler.md:104: for the week menu the last save wins and the user
/// sees "*Namn* sparade veckan" for 30 s; ux-beslut.json D-04 keeps that 30 s
/// window apart from the 7 s undo. [ConflictSnackBar.showWeekSaved] owns the
/// text, the window, the action and the filter (only a week-menu conflict the
/// user's edit lost); this widget only listens to
/// [RealtimeSyncService.conflictStream] while the week menu is open. Without
/// a registered sync service it listens to nothing.
///
/// BUT-2215: it also listens to [weekConflicts], the week menu viewmodel's
/// refused saves of the user's own week, and shows
/// [ConflictSnackBar.showWeekSavedElsewhere] with [onKeepMine] behind
/// "Behåll min".
class VeckomenyConflictNotice extends StatefulWidget {
  const VeckomenyConflictNotice({
    super.key,
    required this.child,
    this.weekConflicts,
    this.onKeepMine,
  });

  final Widget child;
  final Stream<WeekConflict>? weekConflicts;
  final Future<bool> Function(WeekConflict conflict)? onKeepMine;

  @override
  State<VeckomenyConflictNotice> createState() =>
      _VeckomenyConflictNoticeState();
}

class _VeckomenyConflictNoticeState extends State<VeckomenyConflictNotice> {
  StreamSubscription<ConflictEvent>? _sub;
  StreamSubscription<WeekConflict>? _weekSub;

  @override
  void initState() {
    super.initState();
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    _sub = svc?.conflictStream.listen((event) {
      if (!mounted) return;
      ConflictSnackBar.showWeekSaved(context, event);
    });
    _weekSub = widget.weekConflicts?.listen((conflict) {
      final keep = widget.onKeepMine;
      if (!mounted || keep == null) return;
      ConflictSnackBar.showWeekSavedElsewhere(
        context,
        onKeepMine: () => keep(conflict),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _weekSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// P5-U15 (veckogenerering ERROR): placing a generated menu failed.
///
/// Three parts (content-style-guide.md:87-97): what happened ([what], the
/// one message of BUT-2132), what was kept, and Försök igen, which places the
/// same menu again. The week is said to be unchanged only when
/// [weekUnchanged] is true: the rollback may have been skipped, and a message
/// claims only an undo that happened. The generated menu is always kept
/// (produktregler.md:201: a generated result is not in the week until it is
/// placed).
///
/// The publish-first path may already have put the success toast on screen,
/// with an ÄNDRA that opens placement. A queued error would sit behind it for
/// its full duration, so it is hidden first: the last thing the user reads
/// must not be the one that is no longer true.
void showWeekPlacementFailure(
  BuildContext context, {
  required String what,
  required bool weekUnchanged,
  required VoidCallback onRetry,
}) {
  final l10n = context.l10n;
  SnackBarUtils.hide(context);
  SnackBarUtils.showFailure(
    context,
    what: what,
    preserved: weekUnchanged
        ? l10n.weekPlacementFailedWeekUnchanged
        : l10n.weekPlacementFailedMenuKept,
    action: FailureAction.retry(onRetry),
  );
}

/// P6-U02: the receipt after a merge, with Ångra. When the list had been
/// changed on another device before the write, it says so and that nothing
/// was overwritten (BUT-2140; flows-roles-budget.md:18, the user is always
/// told about a conflict).
void showShoppingMergeReceipt(
  BuildContext context,
  MenuShoppingMergeReceipt receipt, {
  required VoidCallback onUndo,
}) {
  final l10n = context.l10n;
  final message = receipt.concurrentChange
      ? l10n.shoppingMergeConcurrentChange(receipt.itemCount)
      : receipt.replaced
      ? l10n.shoppingMergeReplaced(receipt.itemCount, receipt.listName)
      : l10n.shoppingMergeAdded(receipt.itemCount, receipt.listName);
  SnackBarUtils.showUndo(context, message, onUndo: onUndo);
}

/// P5-U16 (veckomeny ERROR): the week's shopping list could not be made.
///
/// Says the week is unchanged (making a list never writes the week) and
/// offers Försök igen, which runs the generation again
/// (content-style-guide.md:87-97).
void showWeekShoppingListFailure(
  BuildContext context, {
  required VoidCallback onRetry,
}) {
  final l10n = context.l10n;
  SnackBarUtils.showFailure(
    context,
    what: l10n.menuShoppingListGenerationFailed,
    preserved: l10n.menuShoppingListGenerationPreserved,
    action: FailureAction.retry(onRetry),
  );
}
