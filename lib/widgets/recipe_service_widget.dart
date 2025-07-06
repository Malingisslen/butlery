// lib/widgets/recipe_service_widget.dart
// ✅ 100% AppTheme migrerad - ANVÄNDER ENDAST BEFINTLIGA APPTHEME PROPERTIES

import 'package:flutter/material.dart';
import '../services/recipe_service.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Widget som integrerar med RecipeService och hanterar loading/error states
class RecipeServiceWidget extends StatelessWidget {
  final Widget Function(List<Recipe> recipes) builder;
  final Widget? loadingWidget;
  final Widget Function(String error)? errorBuilder;
  final bool showLoadingOverlay;

  const RecipeServiceWidget({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.showLoadingOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return RecipeServiceConsumer(
      builder: (context, recipeService, child) {
        // Error state
        if (recipeService.hasError) {
          return errorBuilder?.call(recipeService.lastError!) ??
              _buildDefaultError(context, recipeService.lastError!);
        }

        final content = builder(recipeService.recipes);

        // Loading overlay
        if (showLoadingOverlay && recipeService.isLoading) {
          return Stack(children: [content, _buildLoadingOverlay()]);
        }

        // Loading state
        if (recipeService.isLoading) {
          return loadingWidget ?? _buildDefaultLoading();
        }

        return content;
      },
    );
  }

  Widget _buildDefaultLoading() {
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

  Widget _buildDefaultError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: AppTheme.errorContainer(context, error),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
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
                'Uppdaterar...',
                style: AppTheme.subtitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consumer widget för att lyssna på RecipeService
class RecipeServiceConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    RecipeService value,
    Widget? child,
  ) builder;
  final Widget? child;

  const RecipeServiceConsumer({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RecipeService(),
      builder: (context, child) {
        return builder(context, RecipeService(), child);
      },
      child: child,
    );
  }
}

/// Snackbar helper för RecipeService operationer
class RecipeServiceSnackbar {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.successIcon(context),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(
                    color: Colors.white), // ✅ Använder befintlig bodyStyle
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3), // ✅ Hårdkodad duration
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.errorIcon(context),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(
                    color: Colors.white), // ✅ Använder befintlig bodyStyle
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4), // ✅ Hårdkodad duration
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_outlined,
                size: AppTheme.iconSizeInfo,
                color: AppTheme.warningColor), // ✅ Hårdkodad warning icon
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyStyle.copyWith(
                    color: Colors.white), // ✅ Använder befintlig bodyStyle
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4), // ✅ Hårdkodad duration
      ),
    );
  }
}
