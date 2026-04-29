import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';

// Import the focused components
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/service/service_widgets.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/friends/friend_category_widgets.dart';
import 'package:butlery/widgets/common/permissions/permission_widgets.dart';
import 'package:butlery/widgets/common/feedback/snackbar_widgets.dart';

// Re-export ActionButtonStyle from the focused component
export 'buttons/action_buttons.dart' show ActionButtonStyle;

/// Facade for utility widgets. Delegates to specialized modules.
class UtilityComponents {
  /// Standard action button with loading support and multiple styles.
  static Widget actionButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    ActionButtonStyle style = ActionButtonStyle.primary,
    bool isExpanded = false,
  }) {
    return ActionButtons.actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: style,
      isExpanded: isExpanded,
    );
  }

  /// Square button for grid layouts (recipe upload view)
  static Widget squareButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
  }) {
    return ActionButtons.squareButton(
      context,
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
    );
  }

  /// Large prominent button for important actions
  static Widget largeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    String? loadingText,
    double height = 100,
    EdgeInsets? margin,
  }) {
    return ActionButtons.largeButton(
      context,
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      height: height,
      margin: margin,
    );
  }

  /// Primary action button convenience method
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.primaryButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  /// Secondary action button convenience method
  static Widget secondaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.secondaryButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  /// Outlined action button convenience method
  static Widget outlinedButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    String? loadingText,
    bool isExpanded = false,
  }) {
    return ActionButtons.outlinedButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      isExpanded: isExpanded,
    );
  }

  /// Widget that integrates with RecipeService and handles loading/error states.
  static Widget serviceWidget({
    required Widget Function(List<Recipe> recipes) builder,
    Widget? loadingWidget,
    Widget Function(String error)? errorBuilder,
    bool showLoadingOverlay = false,
  }) {
    return ServiceWidgets.serviceWidget(
      builder: builder,
      loadingWidget: loadingWidget,
      errorBuilder: errorBuilder,
      showLoadingOverlay: showLoadingOverlay,
    );
  }

  /// Generic service widget for other services.
  static Widget genericServiceWidget<T extends Listenable>({
    required T service,
    required Widget Function(BuildContext context, T service) builder,
  }) {
    return ServiceWidgets.genericServiceWidget(
      service: service,
      builder: builder,
    );
  }

  /// Loading overlay displayed over existing content.
  static Widget loadingOverlay({
    Widget? child,
    bool isLoading = false,
    String? loadingMessage,
    Color? overlayColor,
  }) {
    return LoadingWidgets.loadingOverlay(
      child: child,
      isLoading: isLoading,
      loadingMessage: loadingMessage,
      overlayColor: overlayColor,
    );
  }

  /// Error boundary that handles exceptions gracefully.
  static Widget errorBoundary({
    required Widget child,
    Widget? errorWidget,
    Function(Object error, StackTrace stack)? onError,
  }) {
    return LoadingWidgets.errorBoundary(
      child: child,
      errorWidget: errorWidget,
      onError: onError,
    );
  }

  /// Responsive wrapper for adaptive layout.
  static Widget responsiveWrapper({
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    return LoadingWidgets.responsiveWrapper(
      child: child,
      maxWidth: maxWidth,
      padding: padding,
    );
  }

  /// Friend category manager for social sharing.
  static Widget friendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String? title,
    String? subtitle,
  }) {
    return FriendCategoryWidgets.friendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Compact variant for smaller spaces.
  static Widget compactFriendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return FriendCategoryWidgets.compactFriendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      maxHeight: maxHeight,
    );
  }

  /// Action buttons based on user permissions for collaborative editing.
  static Widget permissionsActionButtons({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
    bool isExpanded = true,
  }) {
    return PermissionWidgets.permissionsActionButtons(
      context: context,
      editMode: editMode,
      onSave: onSave,
      onFork: onFork,
      isSaving: isSaving,
      isForking: isForking,
      saveLabel: saveLabel,
      forkLabel: forkLabel,
      isExpanded: isExpanded,
    );
  }

  /// Horizontal layout for permissions buttons (for smaller screens).
  static Widget permissionsActionButtonsHorizontal({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onSave,
    VoidCallback? onFork,
    bool isSaving = false,
    bool isForking = false,
    String? saveLabel,
    String? forkLabel,
  }) {
    return PermissionWidgets.permissionsActionButtonsHorizontal(
      context: context,
      editMode: editMode,
      onSave: onSave,
      onFork: onFork,
      isSaving: isSaving,
      isForking: isForking,
      saveLabel: saveLabel,
      forkLabel: forkLabel,
    );
  }

  /// Show success snackbar.
  static void showSuccessSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showSuccessSnackbar(context, message);
  }

  /// Show error snackbar.
  static void showErrorSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showErrorSnackbar(context, message);
  }

  /// Show error snackbar with "Försök igen" action that re-runs [onRetry].
  ///
  /// Use after an operation has already exhausted in-helper retries
  /// (e.g. `withRetry`) so the user can manually trigger another attempt
  /// without re-navigating.
  static void showErrorSnackbarWithRetry(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    SnackbarWidgets.showErrorSnackbarWithRetry(
      context,
      message,
      onRetry: onRetry,
    );
  }

  /// Show warning snackbar.
  static void showWarningSnackbar(BuildContext context, String message) {
    SnackbarWidgets.showWarningSnackbar(context, message);
  }
}
