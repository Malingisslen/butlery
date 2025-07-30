// lib/views/veckomeny_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/shared_menu.dart';

// ViewModels
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Widgets - MIGRATED: Using LayoutComponents
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/layout_components.dart'; // ✅ MIGRATED: New import
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/input_components.dart';

// Theme
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';

// Utils
import 'package:butlery/core/utils/snackbar_utils.dart';

// Core
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';

// Services
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

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
      SnackBarUtils.showWarning(context, 'Skapa en meny först innan du kan spara den');
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
      SnackBarUtils.showSuccess(context, 'Veckomeny delad!');
    }
  }

  Future<void> _showSocialMenuShareDialog() async {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);

    // Kontrollera att meny finns
    if (!menuViewModel.hasMenu) {
      SnackBarUtils.showWarning(context, 'Skapa en meny först innan du kan dela den');
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
        initialMessage: 'Kolla min veckomeny!',
        availableFriends: availableFriends,
      ),
    );
  }

  // ✅ MIGRERAD: Menu till Shopping List integration med InputComponents
  Future<void> _showShoppingListSelector() async {
    final viewModel = context.read<MenuViewModel>();

    // Kontrollera att meny finns
    if (!viewModel.hasMenu || viewModel.menu.isEmpty) {
      SnackBarUtils.showWarning(context, 'Skapa en meny först innan du kan skapa inköpslista');
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
              backgroundColor: AppColors.error,
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
            icon: Icon(Icons.folder_open, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: _showLoadMenuBottomSheet,
            tooltip: 'Ladda sparad meny',
          ),

          // ✨ NY: Spara meny-knapp (endast när meny finns)
          if (viewModel.hasMenu)
            IconButton(
              icon: Icon(Icons.save, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: _showSaveMenuDialog,
              tooltip: 'Spara meny',
            ),

          // ✨ NY: Enhanced social share ikon
          if (viewModel.hasMenu)
            IconButton(
              icon: Icon(Icons.people_outline, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: _showSocialMenuShareDialog,
              tooltip: _friendsService.friends.isEmpty
                  ? 'Lägg till vänner för att dela'
                  : 'Dela med vänner',
            ),

          // BEFINTLIG: Regular share button
          if (viewModel.hasMenu)
            IconButton(
              icon: Icon(Icons.share, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: _shareMenu,
              tooltip: 'Dela veckomeny',
            ),

          // Clear menu button
          if (viewModel.hasMenu)
            IconButton(
              icon: Icon(Icons.clear, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: _clearMenu,
              tooltip: 'Rensa meny',
            ),

          // Error indicator
          if (viewModel.hasError)
            IconButton(
              icon: const Icon(Icons.error, color: AppColors.error),
              onPressed: () {
                SnackBarUtils.showError(context, viewModel.error!);
              },
              tooltip: 'Visa fel',
            ),
        ],
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                    vertical: AppDimensions.spacingS,
                  ),
                  child: Column(
                    children: [
                      // Prompt-input
                      _buildPromptInput(viewModel),
                      const SizedBox(height: AppDimensions.spacingL),

                      // Generera-knapp
                      _buildGenerateButton(viewModel),
                      const SizedBox(height: AppDimensions.spacingXl),
                    ],
                  ),
                ),
                // Meny-innehåll
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
                    child: _buildMenuContent(viewModel),
                  ),
                ),
              ],
            ),

            // Loading overlay
            if (viewModel.isGenerating)
              ColoredBox(
                color: AppColors.neutralDark.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppDimensions.spacingM),
                        Text(
                          'Genererar meny...',
                          style: AppTextStyles.titleMedium,
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
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
            : null,
      ),
    );
  }

  Widget _buildPromptInput(MenuViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: AppDimensions.iconSizeAction,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                'Vad vill du ha för meny?',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          TextField(
            controller: _promptController,
            enabled: !viewModel.isGenerating,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Ex: 3 middagar, 2 luncher och 1 frukost',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
              suffixIcon: _promptController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
    return Center(
      child: ElevatedButton.icon(
          onPressed: !viewModel.isGenerating && _promptController.text.isNotEmpty
              ? _generateMenu
              : null,
          icon: viewModel.isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neutralLight,
                  ),
                )
              : const Icon(Icons.restaurant_menu),
          label: Text(
            viewModel.isGenerating
                ? 'Genererar...'
                : (viewModel.hasMenu ? 'Generera ny meny' : 'Generera meny'),
          ),
          style: ComponentThemes.primaryButtonStyle,
      ),
    );
  }

  Widget _buildMenuContent(MenuViewModel viewModel) {
    if (!viewModel.hasMenu) {
      return StateWidget.empty(
        title: 'Ingen meny genererad ännu',
        subtitle: 'Skriv vad du vill ha eller tryck på knappen nedan',
        icon: Icons.clear, // Use clear as "no icon" marker
      );
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
        const SizedBox(height: AppDimensions.spacingXxxl + AppDimensions.spacingL),
      ],
    );
  }

  Widget _buildMenuSummary(MenuViewModel viewModel) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
            Icon(
              Icons.restaurant,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingS),
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
        ),
        const SizedBox(height: AppDimensions.spacingL),
      ],
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
        const SizedBox(height: AppDimensions.spacingS),
        Row(
          children: [
            Expanded(
              child: Text(category, style: AppTextStyles.titleLarge),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: AppDimensions.iconSizeAction, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              onPressed: viewModel.isGenerating
                  ? null
                  : () => viewModel.regenerateSection(category),
              tooltip: 'Uppdatera $category',
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
        for (final recipe in recipes)
          ContentCard.compactRecipe(
            recipe: recipe,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/receptDetalj',
                arguments: recipe,
              );
            },
          ),
      ],
    );
  }
}
