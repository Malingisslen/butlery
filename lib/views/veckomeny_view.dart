/// Weekly menu planning view with filter-based generation and social sharing.
library;

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';
import 'package:butlery/widgets/menu/menu_placement_footer.dart';
import 'package:butlery/widgets/menu/veckomeny_draft_resume_card.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart'
    show VeckomenyDialogs;
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_body.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_placement_flow.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_shopping_flow.dart';

export 'package:butlery/views/veckomeny_view/veckomeny_notices.dart';

/// The week menu's root-bar overflow actions.
enum _VeckomenyRootAction { load, save, clear }

/// Weekly menu planning view with natural language input and social sharing.
class VeckomenyView extends StatelessWidget {
  final SharedMenu? sharedMenu;

  /// Opens the shared menu with this `realtime_resources` id live.
  final String? realtimeMenuId;

  const VeckomenyView({super.key, this.sharedMenu, this.realtimeMenuId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MenuViewModel(
            // BUT-2362: marks listed dishes not everyone at home can eat.
            householdAllergens: MealAllergenScope.householdFromLocator,
            mealAllergenScopeOn: MealAllergenScope.isOnFromLocator,
          ),
        ),
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

class _VeckomenyViewContentState extends State<_VeckomenyViewContent>
    with
        VeckomenyPlacementFlow<_VeckomenyViewContent>,
        VeckomenyShoppingFlow<_VeckomenyViewContent> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final UnifiedFriendsService _friendsService =
      ServiceLocator.get<UnifiedFriendsService>();

  VeckomenyViewMode _viewMode = VeckomenyViewMode.lista;

  @override
  VeckomenyViewMode get viewMode => _viewMode;

  @override
  TextEditingController get promptController => _promptController;

  @override
  FocusNode get promptFocusNode => _promptFocusNode;

  @override
  void markRevealing() => setState(() => _revealing = true);

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
    } else {
      // BUT-2157: a kept week draft is offered only on the user's own menu.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(context.read<MenuViewModel>().checkForDraft());
      });
      // BUT-1625: generation reads who is home on the week this screen shows,
      // asked afresh on every generate, re-roll and swap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final menuVm = context.read<MenuViewModel>();
        final calendarVm = context.read<WeeklyMenuPlanViewModel>();
        menuVm.setUnplaceableIdsSource(calendarVm.unplaceableRecipeIds);
        // BUT-2362: likewise who is away decides which dishes some meal
        // can still take when the per-meal allergen choice is on.
        menuVm.setMealScopedIdsSource(calendarVm.mealScopedRecipeIds);
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
  @override
  Future<void> setViewMode(VeckomenyViewMode mode) async {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    await ServiceLocator.get<PersistenceService>().setVeckomenyViewMode(
      mode.name,
    );
  }

  bool _restoringDraft = false;

  bool _revealing = false;

  /// BUT-2157: the draft comes back in Lista, where the suggestion is shown
  /// and placed from, with its prompt.
  Future<void> _restoreDraft() async {
    final menuVm = context.read<MenuViewModel>();
    setState(() => _restoringDraft = true);
    final dropped = await menuVm.restoreDraft();
    if (!mounted) return;
    setState(() => _restoringDraft = false);
    if (dropped == null) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.weekMenuDraftRestoreFailed,
        preserved: context.l10n.weekMenuDraftRestoreFailedKept,
      );
      return;
    }
    _promptController.text = menuVm.lastPrompt;
    await setViewMode(VeckomenyViewMode.lista);
    if (!mounted || dropped == 0) return;
    SnackBarUtils.showInfo(context, context.l10n.weekMenuDraftDropped(dropped));
  }

  void _discardDraft() {
    final menuVm = context.read<MenuViewModel>();
    final draft = menuVm.hideDraft();
    if (draft == null) return;
    SnackBarUtils.showUndoDeferred(
      context,
      context.l10n.draftsDiscarded(1),
      onUndo: () => menuVm.undoDiscardDraft(draft),
      onCommit: () => menuVm.discardDraft(draft),
    );
  }

  /// Shown while the screen holds no menu and no run, and the visible week
  /// is known to be empty. It steps aside while the keyboard is up, as the
  /// placement footer does: the card sits above the prompt in a part of the
  /// body that does not scroll.
  Widget? _buildDraftCard(BuildContext context, MenuViewModel viewModel) {
    final draft = viewModel.pendingDraft;
    if (draft == null ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        widget.realtimeMenuId != null ||
        viewModel.hasMenu ||
        viewModel.isGenerating ||
        context.watch<WeeklyMenuPlanViewModel>().plannedDishCount != 0) {
      return null;
    }
    return Padding(
      padding: AppDimensions.responsiveHorizontalPadding(
        context,
      ).add(const EdgeInsets.only(top: AppDimensions.space8)),
      child: VeckomenyDraftResumeCard(
        draft: draft,
        now: clock.now(),
        restoring: _restoringDraft,
        onRestore: () => unawaited(_restoreDraft()),
        onDiscard: _discardDraft,
      ),
    );
  }

  void _clearMenu() {
    context.read<MenuViewModel>().clearMenu();
    _promptController.clear();
  }

  DetailPaneController? _offeredTo;
  String? _offeredEntryId;

  // Re-offered when the pane appears or the dish to show changes; a pick
  // already made is never replaced by the controller.
  void _offerDish(WeeklyMenuPlanViewModel planVm) {
    final pane = DetailPaneScope.maybeOf(context);
    final entry = planVm.dishToOffer;
    if (pane == null ||
        entry == null ||
        (identical(pane, _offeredTo) && entry.id == _offeredEntryId)) {
      return;
    }
    final recipe = planVm.resolveForNavigation(entry.recipeId);
    if (recipe == null) return;
    _offeredTo = pane;
    _offeredEntryId = entry.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pane.offerFirst(
        RouteSettings(name: Routes.recipeDetail, arguments: recipe),
        key: recipe.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();

    // P5-U26a: the week menu listens for "{namn} sparade veckan", and
    // BUT-2215 for its own week saved on another device.
    final planVm = context.watch<WeeklyMenuPlanViewModel>();
    _offerDish(planVm);
    return VeckomenyConflictNotice(
      weekConflicts: planVm.weekConflicts,
      onKeepMine: planVm.keepMine,
      trayDroppedAsUnsafe: planVm.trayDroppedAsUnsafe,
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
    return ButleryPage.rot(
      title: context.l10n.menuWeek,
      secondaryLine: _weekLine(context, planVm),
      actions: _buildHeaderActions(context, viewModel),
      width: PageWidth.wide,
      body: VeckomenyBody(
        viewModel: viewModel,
        viewMode: _viewMode,
        realtimeMenuId: widget.realtimeMenuId,
        promptController: _promptController,
        promptFocusNode: _promptFocusNode,
        revealing: _revealing,
        draftCard: _buildDraftCard(context, viewModel),
        onSetViewMode: setViewMode,
        onGenerate: generateMenu,
        onCancelPlanning: cancelPlanning,
        onPromptChanged: () => setState(() {}),
        onRevealDone: () {
          if (mounted) setState(() => _revealing = false);
        },
      ),
      // BUT-2275: the footer is the Scaffold's bottom slot, so the shopping
      // button never covers "Jag placerar själv".
      bottomNavigationBar: _buildFooter(context, viewModel),
    );
  }

  /// The calendar's "Till inköpslista", or under a generated list the
  /// placement choice with the same way on (BUT-1241).
  Widget? _buildFooter(BuildContext context, MenuViewModel viewModel) {
    // BUT-2275: the Scaffold lifts the body over the keyboard but not this
    // slot, so the buttons would sit unreachable under it.
    if (viewModel.isGenerating || MediaQuery.viewInsetsOf(context).bottom > 0) {
      return null;
    }
    final planVm = context.watch<WeeklyMenuPlanViewModel>();
    if (_viewMode == VeckomenyViewMode.kalender &&
        widget.realtimeMenuId == null) {
      if (!planVm.hasEntries) return null;
      return VeckomenyShoppingFooter(
        isBusy: planVm.isShoppingFlowRunning,
        onPressed: () => unawaited(openShoppingMerge()),
      );
    }
    if (!viewModel.hasMenu || viewModel.hasError) return null;
    if (widget.realtimeMenuId != null) {
      return VeckomenyShoppingFooter(
        isBusy: planVm.isShoppingFlowRunning,
        onPressed: () => unawaited(openShoppingMerge()),
      );
    }
    return MenuPlacementChoiceFooter(
      isShoppingBusy: planVm.isShoppingFlowRunning,
      onToShopping: () => unawaited(openShoppingMerge()),
      // BUT-1987: the placement state lives on the CALENDAR viewmodel, which
      // owns the write.
      isPlacing: context
          .watch<WeeklyMenuPlanViewModel>()
          .isPlacingGeneratedMenu,
      onPlaceAuto: () => unawaited(onPlaceAutomatically()),
      onPlaceManual: () => unawaited(openPlacement(redoAuto: false)),
    );
  }

  List<Widget> _buildHeaderActions(
    BuildContext context,
    MenuViewModel viewModel,
  ) {
    // The bar gives the icons its own foreground: text.primary on the light
    // root bar in both modes (ButleryTopBar).
    //
    // The group week keeps its icon (it is reached from here and from
    // the group chat, BUT-1971); load, save and clear share one overflow
    // menu, so the title always has room.
    return [
      const GroupMenuEntryButton(),
      ButleryMenu<_VeckomenyRootAction>(
        key: const ValueKey('veckomeny-root-more'),
        semanticLabel: context.l10n.rootBarMoreActions,
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
        choices: [
          // Loading a saved menu would replace the shared one on screen.
          if (widget.realtimeMenuId == null)
            ButleryMenuChoice<_VeckomenyRootAction>(
              value: _VeckomenyRootAction.load,
              icon: ButleryIcons.folder,
              label: context.l10n.menuLoadSaved,
            ),
          if (viewModel.hasMenu)
            ButleryMenuChoice<_VeckomenyRootAction>(
              value: _VeckomenyRootAction.save,
              icon: ButleryIcons.save,
              label: context.l10n.menuSave,
            ),
          // A clear would empty the menu for everyone it is shared with.
          if (viewModel.hasMenu && widget.realtimeMenuId == null)
            ButleryMenuChoice<_VeckomenyRootAction>(
              value: _VeckomenyRootAction.clear,
              icon: ButleryIcons.x,
              label: context.l10n.menuClear,
            ),
        ],
      ),
    ];
  }
}
