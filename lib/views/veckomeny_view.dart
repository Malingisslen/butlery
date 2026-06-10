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
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';

// BUT-408: live cooking session presence
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/cooking/cooking_session_stream.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

/// View-mode toggle for the Veckomeny screen output.
enum VeckomenyViewMode { lista, kalender }

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
  final CookingSessionStreamHolder _sessionsHolder =
      CookingSessionStreamHolder();

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
    _sessionsHolder.dispose();
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadViewModePreference() async {
    final stored =
        await ServiceLocator.get<PersistenceService>().getVeckomenyViewMode();
    if (stored == null || !mounted) return;
    final mode = VeckomenyViewMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => VeckomenyViewMode.lista,
    );
    if (mode != _viewMode) setState(() => _viewMode = mode);
  }

  Future<void> _setViewMode(VeckomenyViewMode mode) async {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    await ServiceLocator.get<PersistenceService>()
        .setVeckomenyViewMode(mode.name);

    // When switching to calendar with a generated menu, apply it.
    if (mode == VeckomenyViewMode.kalender && mounted) {
      final menuVm = context.read<MenuViewModel>();
      final calendarVm = context.read<WeeklyMenuPlanViewModel>();
      if (menuVm.hasMenu) {
        await calendarVm.applyGeneratedMenu(
          menuVm.menu,
          replaceExisting: true,
        );
      }
    }
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

    await menuVm.generateMenu(_promptController.text);
    if (!mounted) return;

    if (_viewMode == VeckomenyViewMode.kalender && menuVm.hasMenu) {
      await calendarVm.applyGeneratedMenu(
        menuVm.menu,
        replaceExisting: true,
      );
    }
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
        title: 'veckans\nmeny',
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
        onPressed: () => _generateWeekShoppingList(planVm.currentWeekStart),
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

  /// BUT-956: aggregate the calendar week's recipes into one shopping list.
  /// Re-entrancy-guarded — a double-tap before the first generation lands
  /// would otherwise race the name-based idempotency into duplicate lists.
  bool _isGeneratingList = false;

  Future<void> _generateWeekShoppingList(DateTime weekStart) async {
    if (_isGeneratingList) return;
    _isGeneratingList = true;
    try {
      final generator = ServiceLocator.get<MenuShoppingListGenerator>();
      final result = await generator.generateForWeek(weekStart);
      if (!mounted) return;
      if (result == null) {
        // null = the generation FAILED (service error path) — distinct from
        // an empty plan, which returns nothingToGenerate.
        SnackBarUtils.showError(
            context, context.l10n.menuShoppingListGenerationFailed);
        return;
      }
      if (result.isEmptyPlan) {
        SnackBarUtils.showWarning(
            context, context.l10n.menuShoppingListGenerationEmpty);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .menuShoppingListGenerated(result.listName, result.itemCount)),
          action: SnackBarAction(
            label: context.l10n.commonShow,
            // The snackbar can outlive this route — guard the late tap.
            onPressed: () {
              if (mounted) {
                Navigator.pushNamed(context, Routes.shoppingList);
              }
            },
          ),
        ),
      );
    } finally {
      _isGeneratingList = false;
    }
  }

  List<Widget> _buildHeaderActions(
      BuildContext context, MenuViewModel viewModel) {
    return [
      _buildViewModeToggle(context),
      // Load menu / template button
      IconButton(
        icon: Icon(Icons.folder_open,
            color: Theme.of(context).colorScheme.onPrimary),
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
          icon:
              Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary),
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
          icon:
              Icon(Icons.clear, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: _clearMenu,
          tooltip: context.l10n.menuClear,
        ),
    ];
  }

  Widget _buildViewModeToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
          border: Border.all(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleButton(
              context,
              label: context.l10n.weeklyMenuToggleList,
              active: _viewMode == VeckomenyViewMode.lista,
              onTap: () => _setViewMode(VeckomenyViewMode.lista),
            ),
            _toggleButton(
              context,
              label: context.l10n.weeklyMenuToggleCalendar,
              active: _viewMode == VeckomenyViewMode.kalender,
              onTap: () => _setViewMode(VeckomenyViewMode.kalender),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yWeeklyMenuViewModeToggle(label),
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: active ? cs.surface : Colors.transparent,
          child: Text(
            label.toLowerCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: active ? cs.onPrimaryContainer : cs.onPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
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
                _buildCookingSessionCard(),
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
                            child: CalendarWeeklyMenuWidget(
                              onRefinePrompt: _promptFocusNode.requestFocus,
                            ),
                          )
                        : MenuContentWidgets.buildMenuContent(
                            context,
                            viewModel: viewModel,
                            onRetry: _promptController.text.isNotEmpty
                                ? () => unawaited(_generateMenu())
                                : null,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Loading overlay
        if (viewModel.isGenerating) _buildLoadingOverlay(context),
      ],
    );
  }

  /// UI Redesign: Uses PeaLoadingAnimation for branded loading experience
  Widget _buildLoadingOverlay(BuildContext context) {
    return PeaLoadingOverlay(
      message: context.l10n.menuGeneratingOverlay,
      subtitle: context.l10n.menuGeneratingSubtitle,
    );
  }

  /// BUT-408: merges presence streams across every FriendCategory the user
  /// belongs to. Hidden entirely when no friend is cooking.
  Widget _buildCookingSessionCard() {
    final module = ServiceLocator.tryGet<CookingSessionModule>();
    final userId = _friendsService.currentUserId;
    if (module == null || userId == null) return const SizedBox.shrink();

    final groups = _friendsService.categoriesList
        .where((FriendCategory c) =>
            c.ownerId == userId || c.friendUserIds.contains(userId))
        .map((g) => g.id)
        .toList(growable: false);
    if (groups.isEmpty) return const SizedBox.shrink();

    _sessionsHolder.refresh(module, groups, userId);
    final stream = _sessionsHolder.stream;
    if (stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<CookingSession>>(
      stream: stream,
      builder: (_, snapshot) {
        final sessions = snapshot.data ?? const <CookingSession>[];
        return CookingSessionCard(sessions: sessions);
      },
    );
  }
}
