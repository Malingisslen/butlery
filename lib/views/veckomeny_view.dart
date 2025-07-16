// lib/views/veckomeny_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Models
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../models/shared_menu.dart';

// ViewModels
import '../viewmodels/menu_viewmodel.dart';
import '../viewmodels/universal_share_dialog_viewmodel.dart';

// Widgets - MIGRATED: Using LayoutComponents
import '../widgets/common/content_card.dart';
import '../widgets/common/layout_components.dart'; // ✅ MIGRATED: New import
import '../widgets/common/state_widget.dart';
import '../widgets/common/universal_share_dialog.dart';
import '../widgets/common/input_components.dart';

// Theme
import '../theme/app_theme.dart';

// Core
import '../core/injection.dart';
import '../core/utils/logger.dart';

// Services
import '../services/share_service.dart';
import '../services/unified/unified_friends_service.dart';

/// ✨ MIGRATED VY MED LAYOUTCOMPONENTS
class VeckomenyView extends StatelessWidget {
  final SharedMenu? sharedMenu;
  
  const VeckomenyView({super.key, this.sharedMenu});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<MenuViewModel>(),
      child: const _VeckomenyViewContent(),
    );
  }
}

class _VeckomenyViewContent extends StatefulWidget {
  const _VeckomenyViewContent();

  @override
  State<_VeckomenyViewContent> createState() => _VeckomenyViewContentState();
}

class _VeckomenyViewContentState extends State<_VeckomenyViewContent> {
  final TextEditingController _promptController = TextEditingController();
  final ShareService _shareService = sl<ShareService>();
  final UnifiedFriendsService _friendsService = sl<UnifiedFriendsService>();

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    setState(() {}); // För att uppdatera knappens enabled-state
  }

  void _generateMenu() {
    final viewModel = context.read<MenuViewModel>();
    viewModel.generateMenu(_promptController.text);
  }

  void _clearMenu() {
    final viewModel = context.read<MenuViewModel>();
    viewModel.clearMenu();
    _promptController.clear();
  }

  // ✅ MIGRATED: Använd LayoutComponents.showSaveMenuDialog
  Future<void> _showSaveMenuDialog() async {
    final viewModel = context.read<MenuViewModel>();

    if (!viewModel.hasMenu) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skapa en meny först innan du kan spara den'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    await LayoutComponents.showSaveMenuDialog(
      context,
      viewModel: viewModel,
      availableFriends: _friendsService.friends,
    );
  }

  // ✅ MIGRATED: Använd LayoutComponents.showLoadMenuDialog
  Future<void> _showLoadMenuBottomSheet() async {
    final viewModel = context.read<MenuViewModel>();

    await LayoutComponents.showLoadMenuDialog(
      context,
      viewModel: viewModel,
    );
  }

  // BEFINTLIG METOD för regular sharing
  Future<void> _shareMenu() async {
    final viewModel = context.read<MenuViewModel>();

    await _shareService.shareWeekMenuFromCategories(
      viewModel.menu,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veckomeny delad!'),
          backgroundColor: AppTheme.successColor,
          duration: AppTheme.wait2s,
        ),
      );
    }
  }

  Future<void> _showSocialMenuShareDialog() async {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);

    // Kontrollera att meny finns
    if (!menuViewModel.hasMenu) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skapa en meny först innan du kan dela den'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Hämta vänner
    List<UserProfile> availableFriends = [];
    try {
      availableFriends = _friendsService.friends;
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte hämta vänner: $e');
    }

    showDialog(
      context: context,
      builder: (context) => UniversalShareDialog.menu(
        menu: menuViewModel.menu,
        viewModel: sl<UniversalShareDialogViewModel>(),
        initialMessage: "Kolla min veckomeny!",
        availableFriends: availableFriends,
      ),
    );
  }

  // ✅ MIGRERAD: Menu till Shopping List integration med InputComponents
  Future<void> _showShoppingListSelector() async {
    final viewModel = context.read<MenuViewModel>();

    // Kontrollera att meny finns
    if (!viewModel.hasMenu || viewModel.menu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skapa en meny först innan du kan skapa inköpslista'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // ✅ MIGRERAD: Använd InputComponents istället för showModalBottomSheet
    await InputComponents.showListSelector(
      context,
      menu: viewModel.menu, // ✅ SKICKA MENY DATA
      onListSelected: () {
        // Lista vald och ingredienser tillagda - stäng modal
        Navigator.pop(context);
      },
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avsluta Butlery?'),
        content: const Text('Vill du verkligen avsluta appen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Avsluta'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MenuViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      // ✅ MIGRATED: Använd LayoutComponents.mainMenu istället för MainLayoutMenu
      child: LayoutComponents.mainMenu(
        currentIndex: 2,
        title: 'Veckomeny',
        actions: [
          // ✨ NY: Ladda meny-knapp
          IconButton(
            icon: AppTheme.actionIcon(context, Icons.folder_open),
            onPressed: _showLoadMenuBottomSheet,
            tooltip: 'Ladda sparad meny',
          ),

          // ✨ NY: Spara meny-knapp (endast när meny finns)
          if (viewModel.hasMenu)
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.save),
              onPressed: _showSaveMenuDialog,
              tooltip: 'Spara meny',
            ),

          // ✨ NY: Enhanced social share ikon
          if (viewModel.hasMenu)
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.people_outline),
              onPressed: _showSocialMenuShareDialog,
              tooltip: _friendsService.friends.isEmpty
                  ? 'Lägg till vänner för att dela'
                  : 'Dela med vänner',
            ),

          // BEFINTLIG: Regular share button
          if (viewModel.hasMenu)
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.share),
              onPressed: _shareMenu,
              tooltip: 'Dela veckomeny',
            ),

          // Clear menu button
          if (viewModel.hasMenu)
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.clear),
              onPressed: _clearMenu,
              tooltip: 'Rensa meny',
            ),

          // Error indicator
          if (viewModel.hasError)
            IconButton(
              icon: AppTheme.errorIcon(context),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.error!),
                    action: SnackBarAction(
                      label: 'Stäng',
                      onPressed: viewModel.clearError,
                    ),
                  ),
                );
              },
              tooltip: 'Visa fel',
            ),
        ],
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(AppTheme.spacingSm),
                  child: Column(
                    children: [
                      // Prompt-input
                      _buildPromptInput(viewModel),
                      SizedBox(height: AppTheme.spacingSmPlus),

                      // Generera-knapp
                      _buildGenerateButton(viewModel),
                      AppTheme.mediumGap,
                    ],
                  ),
                ),
                // Meny-innehåll
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                    ),
                    child: _buildMenuContent(viewModel),
                  ),
                ),
              ],
            ),

            // Loading overlay
            if (viewModel.isGenerating)
              Container(
                color: AppTheme.overlayLight,
                child: Center(
                  child: Container(
                    padding: AppTheme.cardPadding,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: AppTheme.largeRadius,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTheme.mediumLoadingIndicator(),
                        AppTheme.smallGap,
                        Text(
                          'Genererar meny...',
                          style: AppTheme.subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ✅ UPPDATERAD: Floating action button för inköpslista
        floatingActionButton: viewModel.hasMenu
            ? FloatingActionButton.extended(
                onPressed: _showShoppingListSelector, // ✅ MIGRERAD METOD
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Till inköpslista'),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }

  Widget _buildPromptInput(MenuViewModel viewModel) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: AppTheme.iconSizeAction,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Vad vill du ha för meny?',
                style: AppTheme.formLabelStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          AppTheme.smallGap,
          TextField(
            controller: _promptController,
            enabled: !viewModel.isGenerating,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Ex: 3 middagar, 2 luncher och 1 frukost',
              hintStyle: AppTheme.inputHintStyle,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
              suffixIcon: _promptController.text.isNotEmpty
                  ? IconButton(
                      icon: AppTheme.actionIcon(context, Icons.clear),
                      onPressed: () {
                        _promptController.clear();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _generateMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(MenuViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: !viewModel.isGenerating && _promptController.text.isNotEmpty
            ? _generateMenu
            : null,
        icon: viewModel.isGenerating
            ? AppTheme.smallLoadingIndicator()
            : const Icon(Icons.restaurant_menu),
        label: Text(
          viewModel.isGenerating
              ? 'Genererar...'
              : (viewModel.hasMenu ? 'Generera ny meny' : 'Generera meny'),
        ),
        style: AppTheme.primaryButtonStyle,
      ),
    );
  }

  Widget _buildMenuContent(MenuViewModel viewModel) {
    if (!viewModel.hasMenu) {
      return StateWidget.noMenu();
    }

    return ListView(
      children: [
        // Meny-sammanfattning
        _buildMenuSummary(viewModel),

        // Meny-sektioner
        for (final entry in viewModel.menu.entries) ...[
          _buildMenuSection(viewModel, entry.key, entry.value),
          const Divider(),
        ],

        // Extra padding för floating button
        SizedBox(height: AppTheme.spacingXxl + AppTheme.spacingMd),
      ],
    );
  }

  Widget _buildMenuSummary(MenuViewModel viewModel) {
    return Container(
      padding: AppTheme.cardPadding,
      margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: AppTheme.iconSizeAction,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Din veckomeny',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                Text(
                  '${viewModel.totalRecipeCount} recept i ${viewModel.menu.length} kategorier',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    MenuViewModel viewModel,
    String category,
    List<Recipe> recipes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Row(
            children: [
              Expanded(
                child: Text(category, style: AppTheme.sectionHeaderStyle),
              ),
              IconButton(
                icon: AppTheme.actionIcon(context, Icons.refresh),
                onPressed: viewModel.isGenerating
                    ? null
                    : () => viewModel.regenerateSection(category),
                tooltip: 'Uppdatera $category',
              ),
            ],
          ),
        ),
        for (final recipe in recipes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
            child: ContentCard.compactRecipe(
              recipe: recipe,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/receptDetalj',
                  arguments: recipe,
                );
              },
            ),
          ),
      ],
    );
  }
}
