/// Comprehensive universal state widget providing unified interface for all application state representations.
///
/// This widget serves as the central facade for displaying various application states including loading,
/// empty content, error conditions, success messages, and informational displays. It implements intelligent
/// delegation to specialized state modules while maintaining consistent visual design and user experience
/// patterns throughout the application. The widget supports Swedish localization and responsive design.
///
/// **Architecture Integration:**
/// - Implements Universal State Pattern for consistent state representation across all views
/// - Delegates to specialized state modules for optimal performance and maintainability
/// - Provides unified API for all state display scenarios with consistent theming
/// - Supports responsive design patterns for various screen sizes and orientations
/// - Integrates with application theme system for consistent visual appearance
///
/// **State Categories:**
/// - **Loading States**: Spinners, skeleton loaders, and progressive loading indicators
/// - **Empty States**: Content-specific empty scenarios with contextual actions
/// - **Error States**: User-friendly error displays with retry mechanisms
/// - **Success States**: Confirmation messages with optional follow-up actions
/// - **Info States**: Informational messages and guidance for user interactions
/// - **Warning States**: Cautionary messages for potentially destructive actions
///
/// **Key Features:**
/// - Intelligent state delegation to specialized rendering modules
/// - Comprehensive factory constructors for common use cases
/// - Swedish localization support with contextual messaging
/// - Responsive design with adaptive layouts for different screen sizes
/// - Consistent theming and visual design across all state representations
/// - Performance optimization through focused state-specific widgets
///
/// **Usage Examples:**
/// ```dart
/// // Loading state with skeleton
/// StateWidget.skeletonRecipeList(itemCount: 5);
/// 
/// // Empty state with action
/// StateWidget.noRecipes(
///   actionLabel: 'Lägg till recept',
///   onAction: () => navigateToAddRecipe(),
/// );
/// 
/// // Error state with retry
/// StateWidget.error(
///   message: 'Kunde inte ladda recept',
///   onAction: () => retryLoading(),
/// );
/// ```

import 'package:flutter/material.dart';

// Import focused components
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/message_states.dart';

// Export enums for backward compatibility
export 'state/state_enums.dart';

/// Comprehensive universal state widget implementing unified interface for all application state representations.
///
/// This widget serves as the primary facade for displaying various application states through specialized
/// state modules while maintaining consistent API and visual design. It provides intelligent delegation
/// to focused state-specific widgets for optimal performance and supports comprehensive customization
/// options for different contexts and user scenarios.
///
/// **Core Architecture:**
/// - **Universal State Pattern**: Single entry point for all state display scenarios
/// - **Modular Delegation**: Routes to specialized state widgets for optimal rendering
/// - **Consistent Theming**: Unified visual design across all state representations
/// - **Performance Optimization**: Focused widgets eliminate unnecessary complexity
/// - **Responsive Design**: Adaptive layouts for various screen sizes and orientations
///
/// **Swedish Localization:**
/// All state messages and actions are localized for Swedish users with contextual
/// messaging that matches the application's cooking and recipe focus.
class StateWidget extends StatelessWidget {
  /// State type determining which specialized state module to delegate to for rendering
  final StateType type;
  
  /// Primary title text displayed prominently in the state widget
  final String? title;
  
  /// Secondary subtitle text providing additional context information
  final String? subtitle;
  
  /// Main message content for detailed state information and user guidance
  final String? message;
  
  /// Icon displayed with the state message for visual context and recognition
  final IconData? icon;
  
  /// Text label for the primary action button enabling user interaction
  final String? actionLabel;
  
  /// Callback function triggered when the primary action button is pressed
  final VoidCallback? onAction;
  
  /// Custom action widget for advanced interaction scenarios beyond standard buttons
  final Widget? customAction;
  
  /// Specific empty state variant for contextual empty content display
  final EmptyStateVariant? emptyVariant;
  
  /// Loading state variant controlling spinner, skeleton, or progress indicator type
  final LoadingVariant? loadingVariant;
  
  /// Number of skeleton items to display for skeleton loading states
  final int? skeletonItemCount;
  
  /// Custom color for the state icon to match specific design requirements
  final Color? iconColor;
  
  /// Custom size for the state icon to match layout and hierarchy needs
  final double? iconSize;
  
  /// Internal padding around the state content for spacing control
  final EdgeInsets? padding;
  
  /// Controls whether content should be centered or fill available space
  final bool centerContent;

  const StateWidget({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.customAction,
    this.emptyVariant,
    this.loadingVariant,
    this.skeletonItemCount,
    this.iconColor,
    this.iconSize,
    this.padding,
    this.centerContent = true,
  });

  // ===== FACTORY CONSTRUCTORS FÖR BAKÅTKOMPATIBILITET =====

  /// Loading state med spinner
  factory StateWidget.loading({
    String? message,
    LoadingVariant variant = LoadingVariant.spinner,
    int itemCount = 5,
  }) {
    return StateWidget(
      type: StateType.loading,
      message: message,
      loadingVariant: variant,
      skeletonItemCount: itemCount,
    );
  }

  /// Skeleton loading för recept-lista
  factory StateWidget.skeletonRecipeList({
    int itemCount = 5,
  }) {
    return StateWidget(
      type: StateType.loading,
      loadingVariant: LoadingVariant.skeletonRecipeList,
      skeletonItemCount: itemCount,
      centerContent: false,
    );
  }

  /// Skeleton loading för enskilt recept-kort
  factory StateWidget.skeletonRecipeCard() {
    return const StateWidget(
      type: StateType.loading,
      loadingVariant: LoadingVariant.skeletonRecipeCard,
      centerContent: false,
    );
  }

  /// Empty state för "inga recept"
  factory StateWidget.noRecipes({
    String? actionLabel = 'Lägg till recept',
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noRecipes,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "inga sökresultat"
  factory StateWidget.noSearchResults({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noSearchResults,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "inga vänner hittades"
  factory StateWidget.noFriendsSearchResults({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noFriendsSearchResults,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "inga grupper hittades"
  factory StateWidget.noGroupsSearchResults({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noGroupsSearchResults,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "ingen meny"
  factory StateWidget.noMenu({
    String? actionLabel = 'Generera meny',
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noMenu,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "ingen inköpslista"
  factory StateWidget.noShoppingList({
    String? actionLabel = 'Skapa veckomeny',
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noShoppingList,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state för "inga vänner"
  factory StateWidget.noFriends({
    String? actionLabel = 'Lägg till vänner',
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noFriends,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Error state med retry-knapp
  factory StateWidget.error({
    required String message,
    String? actionLabel = 'Försök igen',
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.error,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Success state med bekräftelse
  factory StateWidget.success({
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.success,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Generic empty state med custom innehåll
  factory StateWidget.empty({
    required String title,
    String? subtitle,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? customAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      customAction: customAction,
      emptyVariant: EmptyStateVariant.generic,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case StateType.loading:
        return _buildLoadingState(context);
      case StateType.skeleton:
        return _buildSkeletonState(context);
      case StateType.empty:
        return _buildEmptyState(context);
      case StateType.error:
        return _buildErrorState(context);
      case StateType.success:
        return _buildSuccessState(context);
      case StateType.info:
        return _buildInfoState(context);
      case StateType.warning:
        return _buildWarningState(context);
    }
  }

  /// ===== LOADING STATES (delegerar till LoadingStates) =====

  Widget _buildLoadingState(BuildContext context) {
    if (centerContent) {
      return LoadingStates.buildLoadingState(
        context,
        variant: loadingVariant,
        message: message,
        skeletonItemCount: skeletonItemCount,
      );
    }
    
    // För skeleton lists som inte ska centreras
    return LoadingStates.buildLoadingState(
      context,
      variant: loadingVariant,
      message: message,
      skeletonItemCount: skeletonItemCount,
    );
  }

  Widget _buildSkeletonState(BuildContext context) {
    return _buildLoadingState(context);
  }

  /// ===== EMPTY STATE (delegerar till EmptyStates) =====

  Widget _buildEmptyState(BuildContext context) {
    return EmptyStates.buildEmptyState(
      context,
      variant: emptyVariant,
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      customAction: customAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

  /// ===== ERROR STATE (delegerar till MessageStates) =====

  Widget _buildErrorState(BuildContext context) {
    return MessageStates.buildErrorState(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

  /// ===== SUCCESS STATE (delegerar till MessageStates) =====

  Widget _buildSuccessState(BuildContext context) {
    return MessageStates.buildSuccessState(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

  /// ===== INFO STATE (delegerar till MessageStates) =====

  Widget _buildInfoState(BuildContext context) {
    return MessageStates.buildInfoState(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

  /// ===== WARNING STATE (delegerar till MessageStates) =====

  Widget _buildWarningState(BuildContext context) {
    return MessageStates.buildWarningState(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }
}