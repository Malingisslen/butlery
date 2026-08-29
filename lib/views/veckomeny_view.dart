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
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart'
    show MenuShoppingGenerationResult;
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/menu/menu_placement_viewmodel.dart'
    show PlacementSaveResult;
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/views/menu_placement_view.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/group_menu_entry_button.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/menu/menu_placement_footer.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';
import 'package:butlery/widgets/voice/voice_prompt_button.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

/// Weekly menu planning view with natural language input and social sharing.
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
      final placed = await _applyGeneratedToCalendar(skipConfirm: true);
      if (placed != null && placed > 0 && mounted) {
        _showAutoPlacedToast(placed);
      }
    }
  }

  /// BUT-1241: auto-distribute the generated menu onto the CURRENT week —
  /// the same week the calendar opens on, and the only week where the
  /// today-anchored distribution semantics ("inga recept på passerade
  /// dagar") make sense. Confirms overwrite when the week already has
  /// entries, threads the parsed day pins, and surfaces failures here
  /// (lista mode never renders the calendar VM's error state). Returns the
  /// placed count, or null when cancelled / failed / nothing to place.
  Future<int?> _applyGeneratedToCalendar({bool skipConfirm = false}) async {
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
    );
    if (placed == null && mounted) {
      final error = calendarVm.error;
      if (error != null) SnackBarUtils.showError(context, error);
    }
    return placed;
  }

  /// Footer primary action: auto-place, switch to kalender, offer ÄNDRA.
  Future<void> _onPlaceAutomatically() async {
    final placed = await _applyGeneratedToCalendar();
    if (placed == null || !mounted) return;
    await _setViewMode(VeckomenyViewMode.kalender);
    if (!mounted) return;
    // placed == 0 (everything overflowed) skips the toast — the calendar's
    // overflow tray explains the outcome better than a "0 placed" snackbar.
    if (placed > 0) _showAutoPlacedToast(placed);
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

    return Scaffold(
      appBar: MainViewHeader(
        title: context.l10n.veckomenyHeaderTitle,
        ghostIllustration: VegetableType.peaPod,
        countBadge: viewModel.hasMenu
            ? context.l10n.menuWeekBadgeWithCount(weekNumber, menuItemCount)
            : context.l10n.menuWeekBadge(weekNumber),
        actions: _buildHeaderActions(context, viewModel),
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
    return [
      VeckomenyViewModeToggle(
        mode: _viewMode,
        onSelect: (mode) => unawaited(_setViewMode(mode)),
      ),
      const GroupMenuEntryButton(),
      // Load menu / template button
      IconButton(
        icon: Icon(
          Icons.folder_open,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        onPressed: () => VeckomenyDialogs.showLoadMenuBottomSheet(
          context,
          viewModel: viewModel,
          onTemplateSelected: (prompt) {
            _promptController.text = prompt;
            setState(() {});
          },
        ),
        tooltip: context.l10n.menuLoadSaved,
      ),
      // Save menu button (only when menu exists)
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(
            Icons.save,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => VeckomenyDialogs.showSaveMenuDialog(
            context,
            viewModel: viewModel,
            availableFriends: _friendsService.friends,
          ),
          tooltip: context.l10n.menuSave,
        ),
      // Clear menu button
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(
            Icons.clear,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: _clearMenu,
          tooltip: context.l10n.menuClear,
        ),
    ];
  }

  Widget _buildBody(BuildContext context, MenuViewModel viewModel) {
    return Stack(
      children: [
        Center(
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
                            _promptController.selection =
                                TextSelection.collapsed(
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
                      MenuContentWidgets.buildGenerateButton(
                        context,
                        viewModel: viewModel,
                        hasPrompt: _promptController.text.isNotEmpty,
                        onGenerate: () => unawaited(_generateMenu()),
                      ),
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
                    child: _viewMode == VeckomenyViewMode.kalender
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
        ),
        // Loading overlay
        if (viewModel.isGenerating) const VeckomenyGeneratingOverlay(),
      ],
    );
  }
}
