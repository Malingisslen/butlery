// lib/widgets/state_widget.dart

/// 🔍 AI INFO BLOCK:
/// Component: StateWidget - Universal state handler for all app states
/// File: lib/widgets/state_widget.dart
/// Quick Guide: Replaces multiple state widgets with one flexible component
/// Dependencies IN: AppTheme, Flutter material, UtilityComponents
/// Dependencies OUT: All views that need state display
/// Data flow: State type + data → Visual representation
/// State management: Stateless, receives state from parent
/// Purpose: Centralized state UI with consistent design
/// Common issues: Proper state type handling, theme compliance
/// Test coverage: Unit tests for all state types
/// Performance: Lightweight, no unnecessary rebuilds
/// Analytics: State transitions can be logged
/// Code smells: Clean, single responsibility
/// Connected to: All ViewModels, Views, Services
/// Used in phases: Core UI foundation

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common/utility_components.dart';

/// Enum för olika state-typer
enum StateType {
  loading,
  skeleton,
  empty,
  error,
  success,
  info,
  warning,
}

/// Enum för olika empty state varianter
enum EmptyStateVariant {
  noRecipes,
  noSearchResults,
  noMenu,
  noShoppingList,
  noFriends,
  noCategories,
  noImages,
  noTargets,
  noSavedMenus,
  generic,
}

/// Enum för olika loading varianter
enum LoadingVariant {
  spinner,
  skeletonRecipeCard,
  skeletonRecipeList,
  skeletonGeneric,
  shimmerBox,
}

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

  /// ===== LOADING STATES =====

  Widget _buildLoadingState(BuildContext context) {
    switch (loadingVariant) {
      case LoadingVariant.skeletonRecipeList:
        return _buildSkeletonRecipeList();
      case LoadingVariant.skeletonRecipeCard:
        return _buildSkeletonRecipeCard();
      case LoadingVariant.skeletonGeneric:
        return _buildGenericSkeleton();
      case LoadingVariant.shimmerBox:
        return _buildShimmerBox();
      case LoadingVariant.spinner:
      default:
        return _buildSpinnerLoading(context);
    }
  }

  Widget _buildSpinnerLoading(BuildContext context) {
    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTheme.mediumLoadingIndicator(),
          if (message != null) ...[
            AppTheme.smallGap,
            Text(
              message!,
              style: AppTheme.subtitleStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonRecipeList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      itemCount: skeletonItemCount ?? 5,
      itemBuilder: (context, index) => _buildSkeletonRecipeCard(),
    );
  }

  Widget _buildSkeletonRecipeCard() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          child: Row(
            children: [
              // Bild skeleton
              _SkeletonBox(
                width: 80,
                height: 80,
                borderRadius: AppTheme.smallRadius,
              ),
              SizedBox(width: AppTheme.spacingSm),
              // Text content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel
                    _SkeletonBox(
                      height: 20,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
                    ),
                    // Beskrivning rad 1
                    _SkeletonBox(
                      height: 14,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXxs),
                    ),
                    // Beskrivning rad 2
                    _SkeletonBox(
                      height: 14,
                      width: 150,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
                    ),
                    // Taggar
                    Row(
                      children: [
                        _SkeletonBox(
                          height: 24,
                          width: 60,
                          borderRadius: AppTheme.roundRadius,
                          margin: EdgeInsets.only(right: AppTheme.spacingXs),
                        ),
                        _SkeletonBox(
                          height: 24,
                          width: 80,
                          borderRadius: AppTheme.roundRadius,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericSkeleton() {
    return Column(
      children: [
        _SkeletonBox(height: 20, width: 200),
        AppTheme.smallGap,
        _SkeletonBox(height: 14, width: 150),
        AppTheme.smallGap,
        _SkeletonBox(height: 14, width: 100),
      ],
    );
  }

  Widget _buildShimmerBox() {
    return _SkeletonBox(
      width: 100,
      height: 100,
    );
  }

  Widget _buildSkeletonState(BuildContext context) {
    return _buildLoadingState(context);
  }

  /// ===== EMPTY STATES =====

  Widget _buildEmptyState(BuildContext context) {
    final emptyConfig = _getEmptyStateConfig();

    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ikon
          Icon(
            icon ?? emptyConfig.icon,
            size: iconSize ?? AppTheme.iconSizeEmptyState,
            color: iconColor ?? Theme.of(context).colorScheme.outline,
          ),
          AppTheme.mediumGap,

          // Titel
          Text(
            title ?? emptyConfig.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),

          // Subtitle
          if (subtitle != null || emptyConfig.subtitle != null) ...[
            AppTheme.smallGap,
            Text(
              subtitle ?? emptyConfig.subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],

          // Action
          if (customAction != null) ...[
            AppTheme.largeGap,
            customAction!,
          ] else if (actionLabel != null && onAction != null) ...[
            AppTheme.largeGap,
            // ✅ UPPDATERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: actionLabel!,
              onPressed: onAction,
              icon: emptyConfig.actionIcon,
            ),
          ],
        ],
      ),
    );
  }

  _EmptyStateConfig _getEmptyStateConfig() {
    switch (emptyVariant) {
      case EmptyStateVariant.noRecipes:
        return _EmptyStateConfig(
          icon: Icons.restaurant_menu,
          title: 'Inga recept ännu',
          subtitle:
              'Lägg till ditt första recept genom att trycka på "Lägg till"',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noSearchResults:
        return _EmptyStateConfig(
          icon: Icons.search_off,
          title: 'Inga recept matchade din sökning',
          subtitle: 'Prova att söka på något annat eller rensa sökningen',
          actionIcon: Icons.clear,
        );
      case EmptyStateVariant.noMenu:
        return _EmptyStateConfig(
          icon: Icons.restaurant,
          title: 'Ingen meny genererad ännu',
          subtitle: 'Skriv vad du vill ha eller tryck på knappen nedan',
          actionIcon: Icons.auto_awesome,
        );
      case EmptyStateVariant.noShoppingList:
        return _EmptyStateConfig(
          icon: Icons.shopping_cart_outlined,
          title: 'Ingen meny att skapa inköpslista från',
          subtitle: 'Gå tillbaka och skapa en veckomeny först',
          actionIcon: Icons.restaurant,
        );
      case EmptyStateVariant.noFriends:
        return _EmptyStateConfig(
          icon: Icons.people_outline,
          title: 'Inga vänner ännu',
          subtitle: 'Lägg till vänner för att dela recept och menyer',
          actionIcon: Icons.person_add,
        );
      case EmptyStateVariant.noCategories:
        return _EmptyStateConfig(
          icon: Icons.category,
          title: 'Inga kategorier skapade',
          subtitle: 'Skapa din första kategori för att organisera dina vänner',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noImages:
        return _EmptyStateConfig(
          icon: Icons.image_outlined,
          title: 'Inga bilder tillagda',
          subtitle: 'Lägg till bilder för att göra ditt recept mer attraktivt',
          actionIcon: Icons.add_a_photo,
        );
      case EmptyStateVariant.noTargets:
        return _EmptyStateConfig(
          icon: Icons.group_add,
          title: 'Inga destinationer tillgängliga',
          subtitle:
              'Lägg till vänner eller grupper för att kunna dela innehåll',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.noSavedMenus:
        return _EmptyStateConfig(
          icon: Icons.bookmark_outline,
          title: 'Inga sparade menyer',
          subtitle: 'Skapa och spara menyer för att enkelt ladda dem senare',
          actionIcon: Icons.add,
        );
      case EmptyStateVariant.generic:
      default:
        return _EmptyStateConfig(
          icon: Icons.info_outline,
          title: 'Inget innehåll att visa',
          subtitle: null,
          actionIcon: null,
        );
    }
  }

  /// ===== ERROR STATE =====

  Widget _buildErrorState(BuildContext context) {
    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error ikon
          Icon(
            icon ?? Icons.error_outline,
            size: iconSize ?? AppTheme.iconSizeEmptyState,
            color: iconColor ?? AppTheme.errorColor,
          ),
          AppTheme.mediumGap,

          // Error titel
          Text(
            title ?? 'Ett fel uppstod',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.errorColor,
                ),
            textAlign: TextAlign.center,
          ),

          // Error meddelande
          if (message != null) ...[
            AppTheme.smallGap,
            Container(
              padding: AppTheme.cardPadding,
              margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: AppTheme.errorColor),
              ),
              child: Text(
                message!,
                style: AppTheme.errorTextStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Retry knapp
          if (actionLabel != null && onAction != null) ...[
            AppTheme.largeGap,
            // ✅ UPPDATERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.refresh,
            ),
          ],
        ],
      ),
    );
  }

  /// ===== SUCCESS STATE =====

  Widget _buildSuccessState(BuildContext context) {
    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success ikon
          Icon(
            icon ?? Icons.check_circle_outline,
            size: iconSize ?? AppTheme.iconSizeEmptyState,
            color: iconColor ?? AppTheme.successColor,
          ),
          AppTheme.mediumGap,

          // Success titel
          Text(
            title ?? 'Klart!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.successColor,
                ),
            textAlign: TextAlign.center,
          ),

          // Success meddelande
          if (message != null) ...[
            AppTheme.smallGap,
            Text(
              message!,
              style: AppTheme.successTextStyle,
              textAlign: TextAlign.center,
            ),
          ],

          // Action knapp
          if (actionLabel != null && onAction != null) ...[
            AppTheme.largeGap,
            // ✅ UPPDATERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  /// ===== INFO STATE =====

  Widget _buildInfoState(BuildContext context) {
    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.info_outline,
            size: iconSize ?? AppTheme.iconSizeLarge,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
          ),
          AppTheme.mediumGap,
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            AppTheme.smallGap,
          ],
          if (message != null) ...[
            Text(
              message!,
              style: AppTheme.infoTextStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            AppTheme.largeGap,
            // ✅ UPPDATERAD: ActionButton.outlined → UtilityComponents.outlinedButton
            UtilityComponents.outlinedButton(
              context,
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  /// ===== WARNING STATE =====

  Widget _buildWarningState(BuildContext context) {
    return _buildCenteredContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.warning_outlined,
            size: iconSize ?? AppTheme.iconSizeLarge,
            color: iconColor ?? AppTheme.warningColor,
          ),
          AppTheme.mediumGap,
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.warningColor,
                  ),
              textAlign: TextAlign.center,
            ),
            AppTheme.smallGap,
          ],
          if (message != null) ...[
            Text(
              message!,
              style: AppTheme.warningTextStyle,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            AppTheme.largeGap,
            // ✅ UPPDATERAD: ActionButton.primary → UtilityComponents.primaryButton
            UtilityComponents.primaryButton(
              context,
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  /// ===== HELPER METHODS =====

  Widget _buildCenteredContent(BuildContext context, Widget child) {
    if (!centerContent) return child;

    return Center(
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppTheme.spacingXl),
        child: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }
}

/// ===== SKELETON BOX COMPONENT =====

class _SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: AppTheme.animationDurationSlow,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? AppTheme.smallRadius,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
          stops: const [0.0, 0.5, 1.0],
          transform: _GradientRotation(_shimmerController),
        ),
      ),
    );
  }
}

/// Transform för shimmer-effekt
class _GradientRotation extends GradientTransform {
  final Animation<double> animation;

  const _GradientRotation(this.animation);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double x = animation.value * 3 - 1;
    return Matrix4.translationValues(bounds.width * x, 0, 0);
  }
}

/// ===== CONFIGURATION CLASSES =====

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? actionIcon;

  const _EmptyStateConfig({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionIcon,
  });
}

/// ===== LEGACY ALIASES FÖR BAKÅTKOMPATIBILITET =====

/// Ersätter den gamla EmptyState klassen
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.customAction,
  });

  const EmptyState.noRecipes({
    super.key,
    this.actionLabel = 'Lägg till recept',
    this.onAction,
  })  : icon = Icons.restaurant_menu,
        title = 'Inga recept ännu',
        subtitle =
            'Lägg till ditt första recept genom att trycka på "Lägg till"',
        customAction = null;

  const EmptyState.noSearchResults({
    super.key,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.search_off,
        title = 'Inga recept matchade din sökning',
        subtitle = 'Prova att söka på något annat eller rensa sökningen',
        customAction = null;

  const EmptyState.noMenu({
    super.key,
    this.actionLabel = 'Generera meny',
    this.onAction,
  })  : icon = Icons.restaurant,
        title = 'Ingen meny genererad ännu',
        subtitle = 'Skriv vad du vill ha eller tryck på knappen nedan',
        customAction = null;

  const EmptyState.noShoppingList({
    super.key,
    this.actionLabel = 'Skapa veckomeny',
    this.onAction,
  })  : icon = Icons.shopping_cart_outlined,
        title = 'Ingen meny att skapa inköpslista från',
        subtitle = 'Gå tillbaka och skapa en veckomeny först',
        customAction = null;

  @override
  Widget build(BuildContext context) {
    return StateWidget.empty(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      customAction: customAction,
    );
  }
}

/// Ersätter den gamla SkeletonLoader klassen
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

/// Ersätter RecipeCardSkeleton
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StateWidget.skeletonRecipeCard();
  }
}

/// Ersätter RecipeListSkeleton
class RecipeListSkeleton extends StatelessWidget {
  final int itemCount;

  const RecipeListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return StateWidget.skeletonRecipeList(itemCount: itemCount);
  }
}
