/// Comprehensive weekly menu planning view providing advanced AI-powered meal planning and social sharing for Flutter applications.
///
/// This module implements sophisticated weekly menu ("veckomeny") interface following Single Responsibility Principle,
/// specializing in AI-powered menu generation, meal planning coordination, social sharing, and comprehensive menu management.
/// It provides complete weekly menu interface while maintaining clean separation from business logic, data persistence,
/// and state management through MVVM architecture and migrated component integration.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles weekly menu UI presentation concerns through migrated component architecture:
/// - **AI-Powered Menu Generation**: Advanced meal planning with AI assistance and intelligent recipe recommendations
/// - **Social Sharing Intelligence**: Comprehensive menu sharing with friends, social integration, and collaborative features
/// - **Menu Management System**: Complete menu operations including save, load, clear, and regeneration functionality
/// - **Shopping Integration**: Seamless integration with shopping list creation from menu ingredients
/// - **Swedish Localization Excellence**: Complete Swedish language support for menu operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Menu generation business logic and AI processing (handled by MenuViewModel and menu services)
/// - Social interaction business logic (handled by social services and sharing infrastructure)
/// - Data persistence and menu storage (handled by menu repositories and Firebase services)
/// - Shopping list business logic (handled by shopping services and unified shopping coordination)
///
/// **Weekly Menu View Architecture:**
/// - **Migrated Component Integration**: Modern architecture using LayoutComponents and InputComponents
/// - **AI-Powered Generation**: Intelligent menu creation with user prompts and recipe recommendations
/// - **Social Integration**: Complete sharing functionality with friend selection and social features
/// - **Menu Persistence**: Save and load functionality with menu storage and retrieval coordination
/// - **Shopping List Integration**: Seamless ingredient extraction and shopping list creation
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to weekly menu view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => const VeckomenyView(),
///   ),
/// );
/// 
/// // Navigate with shared menu for collaborative editing
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => VeckomenyView(sharedMenu: collaborativeMenu),
///   ),
/// );
/// 
/// // The view provides comprehensive menu functionality:
/// // - AI-powered menu generation with user prompts and intelligent recommendations
/// // - Menu management with save, load, clear, and section regeneration
/// // - Social sharing with friends and external platform integration
/// // - Shopping list integration with ingredient extraction and list creation
/// // - Collaborative features with shared menu editing and social coordination
/// ```

// lib/views/veckomeny_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Data models for menu and social functionality
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/shared_menu.dart';

// ViewModel integration for menu state management
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Migrated widget components for modern architecture
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/common/input_components.dart';

// Theme system integration
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';

// Utility services for user feedback
import 'package:butlery/core/utils/snackbar_utils.dart';

// Core services and dependency injection
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

// External services for sharing and social functionality
import 'package:butlery/services/share_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
/// Comprehensive weekly menu planning view providing advanced AI-powered meal planning through provider architecture.
///
/// Manages complete weekly menu interface enabling AI-powered menu generation, social sharing, menu persistence,
/// and shopping list integration while maintaining clean separation between UI presentation and business logic
/// through MVVM architecture and modern component integration.
///
/// **Core Responsibilities:**
/// - Advanced weekly menu presentation with AI-powered generation and intelligent recipe recommendations
/// - Provider-based state management with MenuViewModel integration and reactive coordination
/// - Social sharing coordination with friend selection and collaborative menu features
/// - Menu persistence with save and load functionality through modern component architecture
/// - Shopping list integration with seamless ingredient extraction and list creation
class VeckomenyView extends StatelessWidget {
  /// Optional shared menu for collaborative editing and social functionality coordination.
  /// 
  /// Enables collaborative menu editing, shared menu display, and social menu features
  /// when provided, allowing for collaborative meal planning and social coordination.
  final SharedMenu? sharedMenu;
  
  /// Creates comprehensive weekly menu view with optional collaborative menu integration.
  /// 
  /// [sharedMenu] Optional shared menu for collaborative editing and social functionality
  /// 
  /// Establishes weekly menu interface with provider-based state management,
  /// AI-powered generation capabilities, and comprehensive menu functionality
  /// through clean architectural separation and modern component integration.
  const VeckomenyView({super.key, this.sharedMenu});

  /// Comprehensive provider-based widget construction with MenuViewModel integration and content delegation.
  /// 
  /// [context] Build context for provider creation and widget construction coordination
  /// 
  /// Constructs weekly menu view with provider-based state management enabling
  /// comprehensive menu functionality, AI-powered generation, and social features
  /// through MenuViewModel integration and content component delegation.
  /// 
  /// **Provider Architecture:**
  /// - MenuViewModel integration for menu state management and AI-powered generation
  /// - Service locator pattern for dependency injection and service coordination
  /// - Content delegation to stateful content component for lifecycle management
  /// 
  /// Returns provider-wrapped weekly menu view with comprehensive functionality.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<MenuViewModel>(),
      child: const _VeckomenyViewContent(),
    );
  }
}

/// Weekly menu view content managing user input, service integration, and menu lifecycle coordination.
///
/// Handles complete weekly menu state management including prompt input, menu generation,
/// social sharing, and menu persistence while maintaining clean state management
/// and proper resource disposal through comprehensive lifecycle coordination.
class _VeckomenyViewContent extends StatefulWidget {
  /// Creates weekly menu view content with state management and service integration.
  /// 
  /// Establishes stateful menu content enabling prompt input management,
  /// menu generation coordination, and comprehensive menu functionality
  /// through proper state lifecycle and service integration.
  const _VeckomenyViewContent();

  /// Creates weekly menu view content state with service integration and lifecycle management.
  /// 
  /// Establishes stateful menu interface enabling prompt input management,
  /// service integration, and comprehensive menu functionality through
  /// proper state lifecycle and resource management coordination.
  @override
  State<_VeckomenyViewContent> createState() => _VeckomenyViewContentState();
}

/// Weekly menu view content state managing prompt input, service integration, and menu operation coordination.
///
/// Handles complete weekly menu state management including prompt input control, service integration,
/// menu generation coordination, and user interaction handling while maintaining clean state management
/// and proper resource disposal through comprehensive lifecycle management.
class _VeckomenyViewContentState extends State<_VeckomenyViewContent> {
  /// Prompt input controller for AI-powered menu generation and user input management.
  /// 
  /// Manages user prompt input enabling AI-powered menu generation, input validation,
  /// and user interaction coordination throughout menu creation workflows.
  final TextEditingController _promptController = TextEditingController();
  
  /// Share service for external menu sharing and platform integration coordination.
  /// 
  /// Enables external menu sharing with system integration, platform coordination,
  /// and comprehensive sharing functionality through ShareService integration.
  final ShareService _shareService = ServiceLocator.get<ShareService>();
  
  /// Friends service for social features and collaborative menu functionality coordination.
  /// 
  /// Manages social menu features enabling friend selection, collaborative sharing,
  /// and social integration throughout menu operations and sharing workflows.
  final UnifiedFriendsService _friendsService = ServiceLocator.get<UnifiedFriendsService>();

  /// State initialization with prompt input listener setup and lifecycle preparation.
  /// 
  /// Initializes weekly menu state enabling prompt input monitoring, UI state management,
  /// and comprehensive menu functionality through proper listener setup and
  /// state lifecycle coordination.
  /// 
  /// **Initialization Process:**
  /// - Prompt controller listener setup for reactive UI state management
  /// - State preparation for menu generation and user interaction coordination
  /// - Lifecycle management preparation with proper resource handling
  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  /// Comprehensive resource disposal with controller cleanup and listener management.
  /// 
  /// Performs complete resource cleanup preventing memory leaks and ensuring proper
  /// lifecycle management through systematic disposal of controllers, listeners,
  /// and state resources with comprehensive cleanup coordination.
  /// 
  /// **Disposal Process:**
  /// - Prompt controller listener cleanup with proper resource management
  /// - Controller disposal with memory leak prevention
  /// - Proper lifecycle management with systematic resource cleanup
  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  /// Prompt input change handling with reactive UI state management and button coordination.
  /// 
  /// Handles prompt input changes enabling reactive UI updates, button state management,
  /// and user interface coordination through state management and UI responsiveness
  /// with comprehensive user experience optimization.
  /// 
  /// **Change Handling Features:**
  /// - Reactive UI state updates with immediate visual feedback
  /// - Button state management with enabled/disabled coordination
  /// - User experience optimization with responsive interface coordination
  void _onPromptChanged() {
    if (mounted) setState(() {}); // Update button enabled state based on prompt input
  }

  /// AI-powered menu generation with prompt processing and intelligent recipe coordination.
  /// 
  /// Handles menu generation triggering AI-powered meal planning, recipe recommendations,
  /// and comprehensive menu creation through MenuViewModel integration with
  /// prompt processing and intelligent content generation.
  /// 
  /// **Generation Features:**
  /// - AI-powered menu creation with intelligent recipe recommendations
  /// - Prompt processing with user input analysis and menu customization
  /// - Comprehensive meal planning with category organization and recipe coordination
  void _generateMenu() {
    final viewModel = context.read<MenuViewModel>();
    viewModel.generateMenu(_promptController.text);
  }

  /// Comprehensive menu clearing with state reset and input cleanup coordination.
  /// 
  /// Handles complete menu clearing enabling state reset, input cleanup,
  /// and user interface coordination through MenuViewModel integration
  /// with comprehensive state management and UI synchronization.
  /// 
  /// **Clearing Features:**
  /// - Complete menu state reset with comprehensive data cleanup
  /// - Input field clearing with user interface synchronization
  /// - State management coordination with proper cleanup and reset functionality
  void _clearMenu() {
    final viewModel = context.read<MenuViewModel>();
    viewModel.clearMenu();
    _promptController.clear();
  }

  /// Comprehensive menu save dialog with validation and friend integration through migrated components.
  /// 
  /// Presents menu save dialog enabling menu persistence, friend sharing setup,
  /// and comprehensive save functionality through LayoutComponents integration
  /// with validation and user feedback coordination.
  /// 
  /// **Save Dialog Features:**
  /// - Menu validation with user guidance and error prevention
  /// - Friend integration with social sharing setup and collaborative features
  /// - Migrated component architecture with modern dialog presentation
  /// - Swedish localized user feedback with warning messages and guidance
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

  /// Advanced menu load dialog with menu selection and restoration through migrated components.
  /// 
  /// Presents menu load dialog enabling saved menu selection, menu restoration,
  /// and comprehensive load functionality through LayoutComponents integration
  /// with menu browsing and selection coordination.
  /// 
  /// **Load Dialog Features:**
  /// - Saved menu browsing with selection interface and preview functionality
  /// - Menu restoration with comprehensive data loading and state synchronization
  /// - Migrated component architecture with modern dialog presentation
  /// - User-friendly menu selection with intuitive interface and navigation
  Future<void> _showLoadMenuBottomSheet() async {
    final viewModel = context.read<MenuViewModel>();

    await LayoutComponents.showLoadMenuDialog(
      context,
      viewModel: viewModel,
    );
  }

  /// External menu sharing with system integration and platform distribution coordination.
  /// 
  /// Handles external menu sharing enabling system share dialog presentation,
  /// platform integration, and comprehensive sharing functionality through
  /// ShareService coordination with success feedback and user experience optimization.
  /// 
  /// **External Sharing Features:**
  /// - System share dialog integration with platform-specific sharing capabilities
  /// - Menu content formatting with readable presentation and user-friendly format
  /// - Success feedback with Swedish localized messages and user confirmation
  /// - Platform integration with comprehensive sharing options and distribution coordination
  Future<void> _shareMenu() async {
    final viewModel = context.read<MenuViewModel>();

    await _shareService.shareWeekMenuFromCategories(
      viewModel.menu,
    );

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Veckomeny delad!');
    }
  }

  /// Comprehensive social menu sharing dialog with friend selection and collaborative features coordination.
  /// 
  /// Presents social sharing dialog enabling friend selection, collaborative menu sharing,
  /// and comprehensive social functionality through UniversalShareDialog integration
  /// with validation, friend management, and user experience optimization.
  /// 
  /// **Social Sharing Features:**
  /// - Menu validation with user guidance and error prevention
  /// - Friend selection with availability management and social integration
  /// - Collaborative sharing with personalized messages and social coordination
  /// - Error handling with graceful fallback and user feedback management
  /// - Swedish localized interface with intuitive social sharing experience
  Future<void> _showSocialMenuShareDialog() async {
    final menuViewModel = Provider.of<MenuViewModel>(context, listen: false);

    // Validate menu availability before sharing
    if (!menuViewModel.hasMenu) {
      SnackBarUtils.showWarning(context, 'Skapa en meny först innan du kan dela den');
      return;
    }

    // Retrieve available friends with error handling
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
        viewModel: ServiceLocator.get<UniversalShareDialogViewModel>(),
        initialMessage: 'Kolla min veckomeny!',
        availableFriends: availableFriends,
      ),
    );
  }

  /// Advanced shopping list creation from menu with ingredient extraction through migrated components.
  /// 
  /// Handles shopping list creation enabling ingredient extraction, list selection,
  /// and comprehensive shopping integration through InputComponents coordination
  /// with validation, menu processing, and user experience optimization.
  /// 
  /// **Shopping List Integration Features:**
  /// - Menu validation with user guidance and error prevention
  /// - Ingredient extraction with comprehensive recipe processing and content analysis
  /// - Migrated component architecture with modern list selection interface
  /// - Shopping list creation with seamless integration and user-friendly workflow
  /// - Swedish localized user feedback with warning messages and guidance
  Future<void> _showShoppingListSelector() async {
    final viewModel = context.read<MenuViewModel>();

    // Validate menu availability before shopping list creation
    if (!viewModel.hasMenu || viewModel.menu.isEmpty) {
      SnackBarUtils.showWarning(context, 'Skapa en meny först innan du kan skapa inköpslista');
      return;
    }

    // Display shopping list selector with migrated component architecture
    await InputComponents.showListSelector(
      context,
      menu: viewModel.menu, // Pass menu data for ingredient extraction
      onListSelected: () {
        // Shopping list created and ingredients added - close modal
        Navigator.pop(context);
      },
    );
  }

  /// Comprehensive application exit confirmation with user safety and navigation coordination.
  /// 
  /// [context] Build context for dialog presentation and navigation coordination
  /// 
  /// Presents exit confirmation dialog enabling user safety, confirmation workflow,
  /// and comprehensive application exit handling through dialog presentation
  /// with Swedish localized interface and user experience optimization.
  /// 
  /// **Exit Dialog Features:**
  /// - User safety with confirmation dialog and accidental exit prevention
  /// - Swedish localized interface with clear confirmation messaging
  /// - Proper navigation handling with context validation and exit coordination
  /// - System integration with platform-specific exit functionality
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

  /// Comprehensive weekly menu interface construction with migrated components and advanced functionality.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete weekly menu interface featuring AI-powered generation, social sharing,
  /// menu persistence, and shopping integration through migrated component architecture
  /// with comprehensive functionality and Swedish localized user experience.
  /// 
  /// **Interface Architecture:**
  /// - Consumer-based state management with MenuViewModel reactive coordination
  /// - PopScope integration with exit confirmation and user safety features
  /// - Migrated LayoutComponents architecture with modern component integration
  /// - Comprehensive action toolbar with menu operations and social functionality
  /// - Floating action button integration with shopping list creation
  /// 
  /// **Feature Integration:**
  /// - AI-powered menu generation with prompt input and intelligent recommendations
  /// - Social sharing with friend selection and collaborative features
  /// - Menu persistence with save and load functionality through modern dialogs
  /// - Shopping list integration with ingredient extraction and list creation
  /// - Loading overlay with generation progress and user feedback
  /// 
  /// Returns complete weekly menu interface with comprehensive functionality and modern architecture.
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
      // Migrated LayoutComponents integration for modern architecture
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

  /// Comprehensive prompt input construction with AI-powered generation interface and user guidance.
  /// 
  /// [viewModel] MenuViewModel instance for generation state access and loading coordination
  /// 
  /// Constructs AI-powered prompt input interface featuring user guidance, input validation,
  /// and generation preparation enabling intelligent menu creation with comprehensive
  /// user experience and Swedish localized interface coordination.
  /// 
  /// **Prompt Input Features:**
  /// - AI-powered generation interface with user guidance and example prompts
  /// - Input validation with generation state coordination and interaction control
  /// - Swedish localized interface with clear instructions and user-friendly design
  /// - Visual design with consistent theming and modern interface elements
  /// 
  /// Returns prompt input widget with AI-powered generation interface and user guidance.
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

  /// Comprehensive generation button construction with loading states and intelligent generation coordination.
  /// 
  /// [viewModel] MenuViewModel instance for generation state management and loading coordination
  /// 
  /// Constructs AI-powered generation button featuring loading indicators, state management,
  /// and intelligent generation triggering enabling menu creation with comprehensive
  /// user feedback and responsive button design through modern component styling.
  /// 
  /// **Generation Button Features:**
  /// - AI-powered generation triggering with intelligent menu creation
  /// - Loading state integration with progress indicators and interaction control
  /// - Input validation with button state management and user guidance
  /// - Modern component styling with consistent theming and visual design
  /// 
  /// Returns generation button widget with AI-powered functionality and loading state management.
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

  /// Comprehensive menu content construction with AI-generated menu display and empty state management.
  /// 
  /// [viewModel] MenuViewModel instance for menu data access and state management
  /// 
  /// Constructs complete menu content interface featuring AI-generated menu display,
  /// menu sections with regeneration functionality, and empty state management
  /// enabling comprehensive menu presentation with user interaction coordination.
  /// 
  /// **Menu Content Features:**
  /// - AI-generated menu display with organized sections and recipe presentation
  /// - Menu section regeneration with individual section updates and content refresh
  /// - Empty state management with user guidance and generation prompts
  /// - Interactive recipe cards with navigation and detail view integration
  /// 
  /// Returns menu content widget with comprehensive menu display and interaction functionality.
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
