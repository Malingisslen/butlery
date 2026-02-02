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
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/menu/veckomeny_dialogs.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';

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
  final ShareService _shareService = ServiceLocator.get<ShareService>();
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

  Future<void> _shareMenu() async {
    final viewModel = context.read<MenuViewModel>();
    await _shareService.shareWeekMenuFromCategories(viewModel.menu);
    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Veckomeny delad!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) VeckomenyDialogs.showExitDialog(context);
      },
      child: LayoutComponents.mainMenu(
        currentIndex: 2,
        title: 'Veckomeny',
        actions: _buildActions(context, viewModel),
        body: _buildBody(context, viewModel),
        floatingActionButton: viewModel.hasMenu
            ? ActionButtons.actionButton(
                context,
                label: 'Till inkopslista',
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

  List<Widget> _buildActions(BuildContext context, MenuViewModel viewModel) {
    return [
      // Load menu button
      IconButton(
        icon: Icon(Icons.folder_open,
            size: AppDimensions.iconSizeAction,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: AppDimensions.opacityDark)),
        onPressed: () => VeckomenyDialogs.showLoadMenuBottomSheet(
          context,
          viewModel: viewModel,
        ),
        tooltip: 'Ladda sparad meny',
      ),

      // Save menu button (only when menu exists)
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(Icons.save,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: AppDimensions.opacityDark)),
          onPressed: () => VeckomenyDialogs.showSaveMenuDialog(
            context,
            viewModel: viewModel,
            availableFriends: _friendsService.friends,
          ),
          tooltip: 'Spara meny',
        ),

      // Social share button
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(Icons.people_outline,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: AppDimensions.opacityDark)),
          onPressed: () => VeckomenyDialogs.showSocialMenuShareDialog(
            context,
            menuViewModel: viewModel,
            friendsService: _friendsService,
          ),
          tooltip: _friendsService.friends.isEmpty
              ? 'Lagg till vanner for att dela'
              : 'Dela med vanner',
        ),

      // Regular share button
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(Icons.share,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: AppDimensions.opacityDark)),
          onPressed: _shareMenu,
          tooltip: 'Dela veckomeny',
        ),

      // Clear menu button
      if (viewModel.hasMenu)
        IconButton(
          icon: Icon(Icons.clear,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: AppDimensions.opacityDark)),
          onPressed: _clearMenu,
          tooltip: 'Rensa meny',
        ),

      // Error indicator
      if (viewModel.hasError)
        IconButton(
          icon: const Icon(Icons.error, color: AppColors.error),
          onPressed: () => SnackBarUtils.showError(context, viewModel.error!),
          tooltip: 'Visa fel',
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
                    child: MenuContentWidgets.buildMenuContent(
                      context,
                      viewModel: viewModel,
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
    return const PeaLoadingOverlay(
      message: 'Genererar meny...',
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
