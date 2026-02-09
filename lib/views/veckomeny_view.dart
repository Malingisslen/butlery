/// Weekly menu planning view with filter-based generation and social sharing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Weekly menu planning view with natural language input and social sharing.
class VeckomenyView extends StatelessWidget {
  final SharedMenu? sharedMenu;

  const VeckomenyView({super.key, this.sharedMenu});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _PersistentMenuViewModel.instance,
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
  final UnifiedFriendsService _friendsService =
      ServiceLocator.get<UnifiedFriendsService>();

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);

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
    super.dispose();
  }

  void _onPromptChanged() {
    if (mounted) setState(() {});
  }

  void _generateMenu() {
    context.read<MenuViewModel>().generateMenu(_promptController.text);
  }

  void _clearMenu() {
    context.read<MenuViewModel>().clearMenu();
    _promptController.clear();
  }

  /// Get current week number
  int _getCurrentWeekNumber() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final daysSinceFirst = now.difference(firstDayOfYear).inDays;
    return ((daysSinceFirst + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();
    final weekNumber = _getCurrentWeekNumber();
    final menuItemCount = viewModel.hasMenu ? viewModel.totalRecipeCount : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) VeckomenyDialogs.showExitDialog(context);
      },
      child: LayoutComponents.mainMenu(
        currentIndex: 1, // UI Redesign: nav order is recept(0), meny(1), inköp(2), lägg till(3)
        // UI Redesign: Use MainViewHeader with week badge
        appBar: MainViewHeader(
          title: 'veckans\nmeny',
          countBadge: viewModel.hasMenu
              ? context.l10n.menuWeekBadgeWithCount(weekNumber, menuItemCount)
              : context.l10n.menuWeekBadge(weekNumber),
          actions: _buildHeaderActions(context, viewModel),
        ),
        body: _buildBody(context, viewModel),
        floatingActionButton: viewModel.hasMenu
            ? ActionButtons.actionButton(
                context,
                label: context.l10n.menuToShoppingList,
                icon: Icons.shopping_cart,
                onPressed: () => VeckomenyDialogs.showShoppingListSelector(
                  context,
                  viewModel: viewModel,
                ),
                style: ActionButtonStyle.primary,
              )
            : null,
      ),
    );
  }

  List<Widget> _buildHeaderActions(BuildContext context, MenuViewModel viewModel) {
    return [
      // Load menu button
      IconButton(
        icon: const Icon(Icons.folder_open, color: AppColors.headerForeground),
        onPressed: () => VeckomenyDialogs.showLoadMenuBottomSheet(
          context,
          viewModel: viewModel,
        ),
        tooltip: context.l10n.menuLoadSaved,
      ),
      // Save menu button (only when menu exists)
      if (viewModel.hasMenu)
        IconButton(
          icon: const Icon(Icons.save, color: AppColors.headerForeground),
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
          icon: const Icon(Icons.clear, color: AppColors.headerForeground),
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
                Padding(
                  padding: AppDimensions.responsiveContentPadding(context),
                  child: Column(
                    children: [
                      MenuContentWidgets.buildPromptInput(
                        context,
                        controller: _promptController,
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
                        onGenerate: _generateMenu,
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
                    // UI Redesign: Pass retry callback for inline error handling
                    child: MenuContentWidgets.buildMenuContent(
                      context,
                      viewModel: viewModel,
                      onRetry: _promptController.text.isNotEmpty
                          ? _generateMenu
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
}

/// Preserves MenuViewModel state across navigation.
class _PersistentMenuViewModel {
  static MenuViewModel? _instance;

  static MenuViewModel get instance {
    _instance ??= MenuViewModel();
    return _instance!;
  }
}
