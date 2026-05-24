import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

// Import focused components
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/message_states.dart';

export 'state/state_enums.dart';

/// Universal state widget facade. Delegates to specialized state modules.
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

  /// Loading state with pea pod animation.
  ///
  /// UI Redesign: Changed default from spinner to peaAnimation
  /// for branded loading experience.
  factory StateWidget.loading({
    String? message,
    LoadingVariant variant = LoadingVariant.peaAnimation,
    int itemCount = 5,
  }) {
    return StateWidget(
      type: StateType.loading,
      message: message,
      loadingVariant: variant,
      skeletonItemCount: itemCount,
    );
  }

  /// Skeleton loading for recipe list.
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

  /// Skeleton loading for single recipe card.
  factory StateWidget.skeletonRecipeCard() {
    return const StateWidget(
      type: StateType.loading,
      loadingVariant: LoadingVariant.skeletonRecipeCard,
      centerContent: false,
    );
  }

  /// Empty state for "no recipes".
  factory StateWidget.noRecipes({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noRecipes,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state for "no search results".
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

  /// Empty state for "no friends found".
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

  /// Empty state for "no groups found".
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

  /// Empty state for "no menu".
  factory StateWidget.noMenu({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noMenu,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state for "no shopping list".
  factory StateWidget.noShoppingList({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noShoppingList,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Empty state for "no friends".
  factory StateWidget.noFriends({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      emptyVariant: EmptyStateVariant.noFriends,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Error state with retry button.
  factory StateWidget.error({
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.error,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Success state with confirmation.
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

  /// Generic empty state with custom content.
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

  /// BUT-986: branded empty state for notifications. Uses the peaPod
  /// illustration via [EmptyStateVariant.noNotifications].
  factory StateWidget.noNotifications({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      actionLabel: actionLabel,
      onAction: onAction,
      emptyVariant: EmptyStateVariant.noNotifications,
    );
  }

  /// BUT-986: branded empty state for comment threads. Uses the mushroom
  /// illustration via [EmptyStateVariant.noComments].
  factory StateWidget.noComments({
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return StateWidget(
      type: StateType.empty,
      actionLabel: actionLabel,
      onAction: onAction,
      emptyVariant: EmptyStateVariant.noComments,
    );
  }

  /// BUT-979: branded empty state for the groups tab. Uses the peaPod
  /// illustration via [EmptyStateVariant.noGroups]. Pass [onCreateGroup]
  /// to wire the "Create group" CTA — when null the action button is
  /// omitted (display-only mode).
  factory StateWidget.noGroups({
    String? actionLabel,
    VoidCallback? onCreateGroup,
  }) {
    return StateWidget(
      type: StateType.empty,
      actionLabel: actionLabel,
      onAction: onCreateGroup,
      emptyVariant: EmptyStateVariant.noGroups,
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

  Widget _buildLoadingState(BuildContext context) {
    if (centerContent) {
      return LoadingStates.buildLoadingState(
        context,
        variant: loadingVariant,
        message: message,
        skeletonItemCount: skeletonItemCount,
      );
    }

    // For skeleton lists that shouldn't be centered
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

  Widget _buildEmptyState(BuildContext context) {
    // Resolve null actionLabel to l10n defaults for known variants
    final resolvedActionLabel = actionLabel ?? _defaultActionLabel(context);
    return EmptyStates.buildEmptyState(
      context,
      variant: emptyVariant,
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: resolvedActionLabel,
      onAction: onAction,
      customAction: customAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return MessageStates.buildErrorState(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel:
          actionLabel ?? (onAction != null ? context.l10n.commonRetry : null),
      onAction: onAction,
      iconColor: iconColor,
      iconSize: iconSize,
      padding: padding,
    );
  }

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

  /// Resolve default action label for known empty state variants via l10n
  String? _defaultActionLabel(BuildContext context) {
    if (onAction == null) return null;
    switch (emptyVariant) {
      case EmptyStateVariant.noRecipes:
        return context.l10n.stateAddRecipes;
      case EmptyStateVariant.noMenu:
        return context.l10n.stateGenerateMenu;
      case EmptyStateVariant.noShoppingList:
        return context.l10n.stateCreateWeeklyMenu;
      case EmptyStateVariant.noFriends:
        return context.l10n.shareAddFriends;
      default:
        return null;
    }
  }
}
