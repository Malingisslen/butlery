/// lib/widgets/common/utility_components.dart


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/recipe_service.dart';
import '../../core/injection.dart';
import '../../models/recipe.dart';
import '../../models/friend_category.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/friend_categories_service.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/logger.dart';
import 'state_widget.dart';
import '../../models/permissions/edit_mode.dart';

/// UtilityComponents - Den kompletta utility widget API:en
///
/// Konsoliderar ActionButton, RecipeServiceWidget, FriendCategoryManager och utility helpers
/// till en unified API för alla utility patterns i Butlery appen.
class UtilityComponents {
  // ============================================================================
  // === ACTION BUTTON COMPONENTS (från ActionButton widget) ===
  // ============================================================================

  /// Standard action button med loading support och flera styles
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
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveLabel = isLoading ? (loadingText ?? 'Laddar...') : label;

    Widget buttonChild = Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingXs),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: AppTheme.smallLoadingIndicator(),
            )
          else if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingSm),
              child: AppTheme.actionIcon(context, icon),
            ),
          Flexible(
            fit: isExpanded ? FlexFit.tight : FlexFit.loose,
            child: Text(
              effectiveLabel,
              style: AppTheme.buttonTextStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isExpanded ? TextAlign.center : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    Widget button;
    switch (style) {
      case ActionButtonStyle.primary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.primaryButtonStyle,
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.secondary:
        button = ElevatedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.primaryButtonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.secondary,
            ),
          ),
          child: buttonChild,
        );
        break;
      case ActionButtonStyle.outlined:
        button = OutlinedButton(
          onPressed: effectiveOnPressed,
          style: AppTheme.secondaryButtonStyle,
          child: buttonChild,
        );
        break;
    }

    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
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
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.primary,
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
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.secondary,
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
    return actionButton(
      context,
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      loadingText: loadingText,
      style: ActionButtonStyle.outlined,
      isExpanded: isExpanded,
    );
  }

  // ============================================================================
  // === SERVICE INTEGRATION COMPONENTS (från RecipeServiceWidget) ===
  // ============================================================================

  /// Widget som integrerar med RecipeService och hanterar loading/error states
  static Widget serviceWidget({
    required Widget Function(List<Recipe> recipes) builder,
    Widget? loadingWidget,
    Widget Function(String error)? errorBuilder,
    bool showLoadingOverlay = false,
  }) {
    return _RecipeServiceConsumer(
      builder: (context, recipeService, child) {
        // Error state
        if (recipeService.hasError) {
          return errorBuilder?.call(recipeService.lastError!) ??
              _buildDefaultServiceError(context, recipeService.lastError!);
        }

        final content = builder(recipeService.recipes);

        // Loading overlay
        if (showLoadingOverlay && recipeService.isLoading) {
          return Stack(children: [content, loadingOverlay(isLoading: true)]);
        }

        // Loading state
        if (recipeService.isLoading) {
          return loadingWidget ?? _buildDefaultServiceLoading();
        }

        return content;
      },
    );
  }

  /// Generic service widget för andra services
  static Widget genericServiceWidget<T extends Listenable>({
    required T service,
    required Widget Function(BuildContext context, T service) builder,
  }) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, child) => builder(context, service),
    );
  }

  // ============================================================================
  // === LOADING & ERROR UTILITY COMPONENTS ===
  // ============================================================================

  /// Loading overlay som visas över existerande innehåll
  static Widget loadingOverlay({
    Widget? child,
    bool isLoading = false,
    String? loadingMessage,
    Color? overlayColor,
  }) {
    if (!isLoading) {
      return child ?? const SizedBox.shrink();
    }

    final overlay = Container(
      color: overlayColor ?? AppTheme.overlay.withValues(alpha: 0.3),
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
              if (loadingMessage != null) ...[
                AppTheme.smallGap,
                Text(
                  loadingMessage,
                  style: AppTheme.subtitleStyle,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (child != null) {
      return Stack(children: [child, overlay]);
    }
    return overlay;
  }

  /// Error boundary som hanterar exceptions gracefully
  static Widget errorBoundary({
    required Widget child,
    Widget? errorWidget,
    Function(Object error, StackTrace stack)? onError,
  }) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stack) {
          onError?.call(error, stack);
          AppLogger.error('Error boundary caught exception: $error');

          return errorWidget ??
              Center(
                child: Padding(
                  padding: AppTheme.screenPadding,
                  child: AppTheme.errorContainer(
                      context, 'Ett oväntat fel uppstod'),
                ),
              );
        }
      },
    );
  }

  /// Responsive wrapper för adaptiv layout
  static Widget responsiveWrapper({
    required Widget child,
    double? maxWidth,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final effectiveMaxWidth =
            maxWidth ?? (screenWidth > 768 ? 600 : double.infinity);

        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
            padding: padding ?? AppTheme.screenPadding,
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================================
  // === FRIEND CATEGORY MANAGEMENT (från FriendCategoryManager) ===
  // ============================================================================

  /// Komplett friend category manager för social sharing
  static Widget friendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String title = 'Välj vänner',
    String subtitle = 'Välj kategorier eller individuella vänner',
  }) {
    return _FriendCategoryManagerWidget(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Kompakt variant för mindre utrymmen
  static Widget compactFriendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
      child: friendCategoryManager(
        selectedFriendIds: selectedFriendIds,
        onSelectionChanged: onSelectionChanged,
        title: 'Välj vänner',
        subtitle: 'Snabbval via kategorier',
      ),
    );
  }

// ============================================================================
  // === PERMISSIONS ACTION BUTTONS (NYA TILLÄGG FÖR KOLLABORATIV REDIGERING) ===
  // ============================================================================

  /// Action buttons baserat på användares permissions för kollaborativ redigering
  ///
  /// Visar olika knappar beroende på användarens rättigheter:
  /// - Ägare: "Spara ändringar" (standard save)
  /// - Collaborator: "Spara ändringar" + "Spara min kopia" (både save och fork)
  /// - Viewer: "Spara min kopia" (endast fork)
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
    // Dynamiska labels baserat på edit mode
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(editMode);

    switch (editMode) {
      case EditMode.owner:
        // Ägare: Endast "Spara ändringar"
        return primaryButton(
          context,
          label: effectiveSaveLabel,
          onPressed: isSaving ? null : onSave,
          icon: Icons.save,
          isLoading: isSaving,
          loadingText: 'Sparar...',
          isExpanded: isExpanded,
        );

      case EditMode.collaborative:
        // Collaborator: Både "Spara ändringar" och "Spara min kopia"
        return Column(
          children: [
            primaryButton(
              context,
              label: effectiveSaveLabel,
              onPressed: isSaving ? null : onSave,
              icon: Icons.save,
              isLoading: isSaving,
              loadingText: 'Sparar...',
              isExpanded: isExpanded,
            ),
            AppTheme.smallGap,
            outlinedButton(
              context,
              label: effectiveForkLabel,
              onPressed: isForking ? null : onFork,
              icon: Icons.content_copy,
              isLoading: isForking,
              loadingText: 'Skapar kopia...',
              isExpanded: isExpanded,
            ),
          ],
        );

      case EditMode.readOnlyWithFork:
        // Viewer: Endast "Spara min kopia"
        return primaryButton(
          context,
          label: effectiveForkLabel,
          onPressed: isForking ? null : onFork,
          icon: Icons.content_copy,
          isLoading: isForking,
          loadingText: 'Skapar kopia...',
          isExpanded: isExpanded,
        );

      case EditMode.noAccess:
        // Ingen åtkomst: Ingen knapp
        return Container(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.1),
            borderRadius: AppTheme.mediumRadius,
            border: Border.all(color: AppTheme.errorColor),
          ),
          child: Row(
            children: [
              Icon(Icons.block, color: AppTheme.errorColor),
              AppTheme.smallHorizontalGap,
              Text('Ingen åtkomst', style: AppTheme.errorTextStyle),
            ],
          ),
        );
    }
  }

  /// Horizontal layout för permissions buttons (för mindre skärmar)
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
    final effectiveSaveLabel = saveLabel ?? _getSaveLabel(editMode);
    final effectiveForkLabel = forkLabel ?? _getForkLabel(editMode);

    switch (editMode) {
      case EditMode.owner:
        return primaryButton(
          context,
          label: effectiveSaveLabel,
          onPressed: isSaving ? null : onSave,
          icon: Icons.save,
          isLoading: isSaving,
          isExpanded: true,
        );

      case EditMode.collaborative:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: primaryButton(
                context,
                label: effectiveSaveLabel,
                onPressed: isSaving ? null : onSave,
                icon: Icons.save,
                isLoading: isSaving,
              ),
            ),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: outlinedButton(
                context,
                label: 'Kopia',
                onPressed: isForking ? null : onFork,
                icon: Icons.content_copy,
                isLoading: isForking,
              ),
            ),
          ],
        );

      case EditMode.readOnlyWithFork:
        return primaryButton(
          context,
          label: effectiveForkLabel,
          onPressed: isForking ? null : onFork,
          icon: Icons.content_copy,
          isLoading: isForking,
          isExpanded: true,
        );

      case EditMode.noAccess:
        return SizedBox.shrink(); // Ingen knapp för ingen åtkomst
    }
  }

  /// Helper för att få rätt save label baserat på edit mode
  static String _getSaveLabel(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
        return 'Spara ändringar';
      case EditMode.collaborative:
        return 'Spara ändringar';
      case EditMode.readOnlyWithFork:
        return 'Spara min kopia'; // ReadOnly kan bara fork:a
      case EditMode.noAccess:
        return 'Ingen åtkomst'; // Används aldrig
    }
  }

  /// Helper för att få rätt fork label baserat på edit mode
  static String _getForkLabel(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
        return 'Spara som ny'; // Används sällan
      case EditMode.collaborative:
        return 'Spara min kopia';
      case EditMode.readOnlyWithFork:
        return 'Spara min kopia';
      case EditMode.noAccess:
        return 'Ingen åtkomst'; // Används aldrig
    }
  }

  // ============================================================================
  // === SNACKBAR UTILITIES (från RecipeServiceSnackbar) ===
  // ============================================================================

  /// Visa success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.successIcon(context),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: AppTheme.wait3s,
      ),
    );
  }

  /// Visa error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.errorIcon(context),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: AppTheme.snackbarDuration,
      ),
    );
  }

  /// Visa warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              size: AppTheme.iconSizeInfo,
              color: AppTheme.warningColor,
            ),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(color: AppTheme.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        duration: AppTheme.snackbarDuration,
      ),
    );
  }

  // ============================================================================
  // === PRIVATE HELPER METHODS ===
  // ============================================================================

  static Widget _buildDefaultServiceLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppTheme.mediumLoadingIndicator(),
          AppTheme.mediumGap,
          Text(
            'Laddar recept...',
            style: AppTheme.subtitleStyle,
          ),
        ],
      ),
    );
  }

  static Widget _buildDefaultServiceError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: AppTheme.errorContainer(context, error),
      ),
    );
  }
}

// ============================================================================
// === SUPPORTING ENUMS & CLASSES ===
// ============================================================================

enum ActionButtonStyle { primary, secondary, outlined }

// ============================================================================
// === PRIVATE IMPLEMENTATION CLASSES ===
// ============================================================================

/// Consumer widget för att lyssna på RecipeService
class _RecipeServiceConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    RecipeService value,
    Widget? child,
  ) builder;

  const _RecipeServiceConsumer({required this.builder});

  @override
  Widget build(BuildContext context) {
    final recipeService = sl<RecipeService>();
    return ListenableBuilder(
      listenable: recipeService,
      builder: (context, _) {
        return builder(context, recipeService, null);
      },
    );
  }
}

/// Internal implementation av FriendCategoryManager
class _FriendCategoryManagerWidget extends StatefulWidget {
  final List<String> selectedFriendIds;
  final Function(List<String>) onSelectionChanged;
  final bool allowMultipleCategories;
  final String title;
  final String subtitle;

  const _FriendCategoryManagerWidget({
    required this.selectedFriendIds,
    required this.onSelectionChanged,
    this.allowMultipleCategories = true,
    this.title = 'Välj vänner',
    this.subtitle = 'Välj kategorier eller individuella vänner',
  });

  @override
  State<_FriendCategoryManagerWidget> createState() =>
      _FriendCategoryManagerWidgetState();
}

class _FriendCategoryManagerWidgetState
    extends State<_FriendCategoryManagerWidget> {
  late final Set<String> _selectedCategories;
  late final Set<String> _selectedFriends;

  @override
  void initState() {
    super.initState();
    _selectedCategories = <String>{};
    _selectedFriends = Set.from(widget.selectedFriendIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoriesService = context.read<FriendCategoriesService>();
      final friendsViewModel = context.read<FriendsViewModel>();

      if (categoriesService.categories.isEmpty) {
        categoriesService.refresh();
      }
      if (friendsViewModel.friends.isEmpty) {
        friendsViewModel.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FriendCategoriesService, FriendsViewModel>(
      builder: (context, categoriesService, friendsVM, child) {
        if (categoriesService.isLoading || friendsVM.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTheme.mediumLoadingIndicator(),
                AppTheme.mediumGap,
                Text(
                  'Laddar vänner och kategorier...',
                  style: AppTheme.subtitleStyle,
                ),
              ],
            ),
          );
        }

        if (categoriesService.hasError) {
          return AppTheme.errorContainer(
            context,
            categoriesService.error ?? 'Kunde inte ladda kategorier',
          );
        }

        if (friendsVM.hasError) {
          return AppTheme.errorContainer(
            context,
            friendsVM.error ?? 'Kunde inte ladda vänner',
          );
        }

        final categories = categoriesService.categoriesWithFriends;
        final friends = friendsVM.friends;

        if (categories.isEmpty && friends.isEmpty) {
          return StateWidget.empty(
            title: 'Inga vänner eller kategorier',
            subtitle: 'Lägg till vänner och skapa kategorier först',
            icon: Icons.people_outline,
            actionLabel: 'Hantera vänner',
            onAction: () => Navigator.pushNamed(context, '/friends'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            AppTheme.mediumGap,
            if (categories.isNotEmpty) ...[
              _buildCategorySection(categories, categoriesService),
              AppTheme.largeGap,
            ],
            if (friends.isNotEmpty) ...[
              _buildIndividualFriendsSection(friends),
              AppTheme.mediumGap,
            ],
            if (_selectedFriends.isNotEmpty) ...[
              _buildSelectionSummary(),
              AppTheme.mediumGap,
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (widget.subtitle.isNotEmpty) ...[
          AppTheme.smallGap,
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySection(
      List<FriendCategory> categories, FriendCategoriesService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppTheme.smallHorizontalGap,
            Text(
              'Kategorier',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        Text(
          'Välj hela kategorier för snabb delning',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AppTheme.smallGap,
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingXs,
          children: categories.map((category) {
            final isSelected = _selectedCategories.contains(category.id);
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category.emoji != null && category.emoji!.isNotEmpty) ...[
                    Text(category.emoji!),
                    SizedBox(width: AppTheme.spacingXs),
                  ],
                  Text(category.name),
                  SizedBox(width: AppTheme.spacingXs),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.neutralLight.withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.friendCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              onSelected: (selected) => _toggleCategory(category, service),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIndividualFriendsSection(List<dynamic> friends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppTheme.smallHorizontalGap,
            Text(
              'Individuellt val',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        AppTheme.smallGap,
        Text(
          'Välj specifika vänner från din vänlista',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AppTheme.smallGap,
        Container(
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: friends.isEmpty
              ? StateWidget.empty(
                  title: 'Inga vänner att visa',
                  subtitle: 'Lägg till vänner först',
                  icon: Icons.people_outline,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppTheme.spacingXs),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = _selectedFriends.contains(friend.uid);

                    return Card(
                      elevation: 0,
                      margin:
                          EdgeInsets.symmetric(vertical: AppTheme.spacingXxs),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) => _toggleFriend(friend.uid),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: friend.bio != null && friend.bio!.isNotEmpty
                            ? Text(
                                friend.bio!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXxs,
                        ),
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: AppTheme.neutralLight,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.group,
              color: AppTheme.neutralLight,
              size: AppTheme.iconSizeInfo,
            ),
          ),
          AppTheme.smallHorizontalGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valda vänner',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${_selectedFriends.length} ${_selectedFriends.length == 1 ? 'vän vald' : 'vänner valda'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          if (_selectedFriends.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllSelections,
              icon: const Icon(Icons.clear, size: AppTheme.iconSizeInfo),
              label: const Text('Rensa'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleCategory(
      FriendCategory category, FriendCategoriesService service) {
    setState(() {
      if (_selectedCategories.contains(category.id)) {
        _selectedCategories.remove(category.id);
        for (final friendId in category.friendUserIds) {
          _selectedFriends.remove(friendId);
        }
        AppLogger.info('🏷️ Kategori "${category.name}" avmarkerad');
      } else {
        if (widget.allowMultipleCategories || _selectedCategories.isEmpty) {
          _selectedCategories.add(category.id);
          _selectedFriends.addAll(category.friendUserIds);
          AppLogger.info(
              '🏷️ Kategori "${category.name}" vald (${category.friendCount} vänner)');
        } else {
          _selectedCategories.clear();
          _selectedFriends.clear();
          _selectedCategories.add(category.id);
          _selectedFriends.addAll(category.friendUserIds);
          AppLogger.info(
              '🏷️ Kategori "${category.name}" vald (ersatt tidigare val)');
        }
      }
    });
    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedFriends.contains(friendId)) {
        _selectedFriends.remove(friendId);
        AppLogger.info('👤 Vän avmarkerad');
      } else {
        _selectedFriends.add(friendId);
        AppLogger.info('👤 Vän vald');
      }
    });
    widget.onSelectionChanged(_selectedFriends.toList());
  }

  void _clearAllSelections() {
    setState(() {
      _selectedCategories.clear();
      _selectedFriends.clear();
    });
    widget.onSelectionChanged([]);
    AppLogger.info('🗑️ Alla val rensade');
  }
}
