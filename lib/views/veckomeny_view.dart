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
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart'
    show MenuShoppingGenerationResult;
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart'
    show PlacementSaveResult;
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/menu/menu_placement_footer.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/widgets/realtime/conflict_snackbar.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';
import 'package:butlery/widgets/voice/voice_prompt_button.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

/// Weekly menu planning view with natural language input and social sharing.
/// The week menu's root-bar overflow actions.
enum _VeckomenyRootAction { load, save, clear }

class VeckomenyView extends StatelessWidget {
  final SharedMenu? sharedMenu;

  const VeckomenyView({super.key, this.sharedMenu});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MenuViewModel()),
        ChangeNotifierProvider(
          create: (_) => ServiceLocator.get<WeeklyMenuPlanViewModel>(),
        ),
      ],
      child: _VeckomenyViewContent(sharedMenu: sharedMenu),
    );
  }
}

class _VeckomenyViewContent extends StatefulWidget {
  final SharedMenu? sharedMenu;

  const _VeckomenyViewContent({this.sharedMenu});

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

    // Load shared menu if provided
    if (widget.sharedMenu != null) {
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
    if (stored != null) {
      final mode = VeckomenyViewMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => VeckomenyViewMode.lista,
      );
      if (mode != _viewMode) setState(() => _viewMode = mode);
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
    await menuVm.generateMenu(_promptController.text);
    if (!mounted) return;

    if (_viewMode == VeckomenyViewMode.kalender && menuVm.hasMenu) {
      // Overwrite was already confirmed above.
      //
      // BUT-2129: announced at the publish, not at the ack. Reading the return
      // value left this path silent offline — the save never acks, so the
      // confirmation never arrived over a week the user could already see.
      await _applyGeneratedToCalendar(
        skipConfirm: true,
        onPublished: (placed) {
          if (!mounted) return;
          if (placed > 0) _showAutoPlacedToast(placed);
        },
      );
    }
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
        // The publish-first path may already have put the success toast on
        // screen, and it carries an ÄNDRA action that opens placement. A
        // queued error would sit behind
        // it for its full duration; hiding it first is what stops the last
        // thing the user reads from being the one that is no longer true.
        SnackBarUtils.hide(context);
        SnackBarUtils.showError(context, error);
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
    await _applyGeneratedToCalendar(
      onPublished: (placed) {
        if (!mounted) return;
        unawaited(_setViewMode(VeckomenyViewMode.kalender));
        // placed == 0 (everything overflowed) skips the toast — the calendar's
        // overflow tray explains the outcome better than a "0 placed" snackbar.
        if (placed > 0) _showAutoPlacedToast(placed);
      },
    );
  }

  void _showAutoPlacedToast(int placed) {
    SnackBarUtils.showSuccessWithAction(
      context,
      context.l10n.menuAutoPlacedToast(placed),
      actionLabel: context.l10n.menuAutoPlacedChangeAction,
      onAction: () => unawaited(_openPlacement(redoAuto: true)),
      duration: const Duration(seconds: 7),
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

  /// Get current week number
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();
    final weekNumber = IsoWeekUtils.isoWeekNumber(clock.now());
    final menuItemCount = viewModel.hasMenu ? viewModel.totalRecipeCount : 0;

    // The root bar (Komponentark v1:60-68; Skarmar v12 del 1 #veckomeny,
    // #tomvecka): "Veckomeny" with the week and the number of dishes on the
    // line under it, and the Lista/Kalender tabs under the bar.
    //
    // P5-U26a: the week menu listens for "{namn} sparade veckan".
    return VeckomenyConflictNotice(
      child: _buildScaffold(context, viewModel, weekNumber, menuItemCount),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    MenuViewModel viewModel,
    int weekNumber,
    int menuItemCount,
  ) {
    return Scaffold(
      appBar: ButleryTopBar.rot(
        title: context.l10n.menuWeek,
        secondaryLine: viewModel.hasMenu
            ? context.l10n.menuWeekBadgeWithCount(weekNumber, menuItemCount)
            : context.l10n.menuWeekBadgeEmpty(weekNumber),
        actions: _buildHeaderActions(context, viewModel),
        bottom: VeckomenyViewModeToggle(
          mode: _viewMode,
          onSelect: (mode) => unawaited(_setViewMode(mode)),
        ),
      ),
      body: _buildBody(context, viewModel),
      floatingActionButton: _buildShoppingFab(context, viewModel),
    );
  }

  /// Mode-aware menu→shopping FAB: the generated-menu (lista) mode keeps the
  /// existing per-recipe list-selector flow; the calendar (kalender) mode
  /// generates the BUT-956 aggregated week list from the plan.
  Widget? _buildShoppingFab(BuildContext context, MenuViewModel viewModel) {
    if (_viewMode == VeckomenyViewMode.kalender) {
      final planVm = context.watch<WeeklyMenuPlanViewModel>();
      if (!planVm.hasEntries) return null;
      return ActionButtons.actionButton(
        context,
        label: context.l10n.menuToShoppingList,
        icon: Icons.shopping_cart,
        // An unacked save does not lock this button (BUT-1975).
        // Generate-vs-generate re-entrancy still holds: `generateShoppingList`
        // runs through `executeAsync`, which does set the flag.
        isLoading: planVm.isLoading,
        onPressed: _generateWeekShoppingList,
        style: ActionButtonStyle.primary,
      );
    }
    if (!viewModel.hasMenu) return null;
    return ActionButtons.actionButton(
      context,
      label: context.l10n.menuToShoppingList,
      icon: Icons.shopping_cart,
      onPressed: () => VeckomenyDialogs.showShoppingListSelector(
        context,
        viewModel: viewModel,
      ),
      style: ActionButtonStyle.primary,
    );
  }

  /// BUT-956/BUT-1234: generation lives on the ViewModel — the view only
  /// triggers it and renders the result as snackbars (null = failure,
  /// alreadyRunning = silence, empty-plan sentinel = warning, otherwise
  /// success).
  Future<void> _generateWeekShoppingList() async {
    final result = await context
        .read<WeeklyMenuPlanViewModel>()
        .generateShoppingList();
    if (!mounted) return;
    if (result == null) {
      SnackBarUtils.showError(
        context,
        context.l10n.menuShoppingListGenerationFailed,
      );
      return;
    }
    // A double-tap raced an in-flight generation — the first call's
    // snackbar will speak for both.
    if (identical(result, MenuShoppingGenerationResult.alreadyRunning)) {
      return;
    }
    if (result.isEmptyPlan) {
      SnackBarUtils.showWarning(
        context,
        context.l10n.menuShoppingListGenerationEmpty,
      );
      return;
    }
    // BUT-1613: when one or more meals were scaled to who's home, explain the
    // adjusted quantities so a shrunk list doesn't read as a bug. Shown on the
    // root messenger, so it rides over the navigation below.
    if (result.scaledMeals > 0) {
      SnackBarUtils.showInfo(
        context,
        context.l10n.menuShoppingScaledToPresence,
      );
    }
    // BUT-900 follow-on: navigate straight to the generated list (mirrors the
    // lista-mode FAB) instead of a toast-only "VISA" the user can miss — the
    // list view itself is the confirmation. (mounted already guarded above; only
    // synchronous checks sit between, so no second guard is needed here.)
    Navigator.pushNamed(context, Routes.shoppingList);
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
      PopupMenuButton<_VeckomenyRootAction>(
        key: const ValueKey('veckomeny-root-more'),
        icon: const Icon(Icons.more_vert),
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
          _rootItem(
            _VeckomenyRootAction.load,
            Icons.folder_open,
            context.l10n.menuLoadSaved,
          ),
          if (viewModel.hasMenu)
            _rootItem(
              _VeckomenyRootAction.save,
              Icons.save,
              context.l10n.menuSave,
            ),
          if (viewModel.hasMenu)
            _rootItem(
              _VeckomenyRootAction.clear,
              Icons.clear,
              context.l10n.menuClear,
            ),
        ],
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
          Icon(icon, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingM),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }

  /// The view's one saffron action (Komponentark v1:843-844; Skarmar v12
  /// del 1 #veckomeny draws "Generera" as the only saffron button). While
  /// the week is planned it keeps its shape and gets the plate line along
  /// its bottom edge (Komponentark v1:372).
  Widget _buildGenerateButton(BuildContext context, MenuViewModel viewModel) {
    final hasPrompt = _promptController.text.isNotEmpty;
    return Center(
      key: const ValueKey('test-veckomeny-generate'),
      child: Semantics(
        identifier: 'btn-generate-menu',
        child: HeroButton(
          label: viewModel.hasMenu
              ? context.l10n.menuGenerateNew
              : context.l10n.menuGenerate,
          busy: viewModel.isGenerating,
          busyLabel: context.l10n.weekMenuPlanningTitle,
          onPressed: hasPrompt ? () => unawaited(_generateMenu()) : null,
        ),
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
            Expanded(
              child: Padding(
                padding: AppDimensions.responsiveHorizontalPadding(context),
                child: viewModel.isGenerating
                    // The week while it is planned: the plate line with
                    // text in the content area, never an overlay over the
                    // view (Skarmar v12 del 1 #veckogenererarpanel;
                    // ux-beslut.json D-03).
                    ? const Align(
                        alignment: Alignment.topCenter,
                        child: VeckomenyGeneratingOverlay(),
                      )
                    : _viewMode == VeckomenyViewMode.kalender
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
                            child: MenuContentWidgets.buildMenuContent(
                              context,
                              viewModel: viewModel,
                              onRetry: _promptController.text.isNotEmpty
                                  ? () => unawaited(_generateMenu())
                                  : null,
                            ),
                          ),
                          // BUT-1241: explicit placement choice for the
                          // generated result.
                          if (viewModel.hasMenu &&
                              !viewModel.isGenerating &&
                              !viewModel.hasError)
                            MenuPlacementChoiceFooter(
                              // BUT-1987: the placement state lives on the
                              // CALENDAR viewmodel, which owns the write.
                              isPlacing: context
                                  .watch<WeeklyMenuPlanViewModel>()
                                  .isPlacingGeneratedMenu,
                              onPlaceAuto: () =>
                                  unawaited(_onPlaceAutomatically()),
                              onPlaceManual: () => unawaited(
                                _openPlacement(redoAuto: false),
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

/// P5-U26a: mounts P3-U08's week conflict snackbar on the week menu.
///
/// produktregler.md:104: for the week menu the last save wins and the user
/// sees "*Namn* sparade veckan" for 30 s; ux-beslut.json D-04 keeps that 30 s
/// window apart from the 7 s undo. [ConflictSnackBar.showWeekSaved] owns the
/// text, the window, the action and the filter (only a week-menu conflict the
/// user's edit lost); this widget only listens to
/// [RealtimeSyncService.conflictStream] while the week menu is open. Without
/// a registered sync service it listens to nothing.
class VeckomenyConflictNotice extends StatefulWidget {
  const VeckomenyConflictNotice({super.key, required this.child});

  final Widget child;

  @override
  State<VeckomenyConflictNotice> createState() =>
      _VeckomenyConflictNoticeState();
}

class _VeckomenyConflictNoticeState extends State<VeckomenyConflictNotice> {
  StreamSubscription<ConflictEvent>? _sub;

  @override
  void initState() {
    super.initState();
    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    _sub = svc?.conflictStream.listen((event) {
      if (!mounted) return;
      ConflictSnackBar.showWeekSaved(context, event);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
