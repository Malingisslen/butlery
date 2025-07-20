// lib/widgets/state_widget.dart

import 'package:flutter/material.dart';

// Import focused components
import 'state/state_enums.dart';
import 'state/loading_states.dart';
import 'state/empty_states.dart';
import 'state/message_states.dart';

// Export enums and legacy classes for backward compatibility
export 'state/state_enums.dart';
export 'state/legacy_state_widgets.dart';

/// 🔥 UNIVERSAL STATE WIDGET
/// Ersätter: EmptyState, SkeletonLoader, och alla _buildEmptyState metoder
class StateWidget extends StatelessWidget {
  final StateType type;
  final String? title;
  final String? subtitle;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customAction;
  final EmptyStateVariant? emptyVariant;
  final LoadingVariant? loadingVariant;
  final int? skeletonItemCount;
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsets? padding;
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