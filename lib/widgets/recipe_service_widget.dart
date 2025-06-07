// lib/widgets/recipe_service_widget.dart

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
          Text('Laddar recept...', style: AppTheme.subtitleStyle),
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
      color: Colors.black26,
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
              Text('Uppdaterar...', style: AppTheme.subtitleStyle),
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
  )
  builder;
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
            SizedBox(width: AppTheme.spacingSm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.errorIcon(context),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            AppTheme.warningIcon(context),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
