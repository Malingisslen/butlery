// lib/widgets/common/service/service_widgets.dart

import 'package:flutter/material.dart';
import '../../../models/recipe_unified.dart';
import '../../../services/unified/unified_recipe_service.dart';
import '../../../core/injection.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';

/// ServiceWidgets - Service integration widgets
///
/// Provides widgets that integrate with services and handle loading/error states.
class ServiceWidgets {
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
          return Stack(children: [content, _buildLoadingOverlay()]);
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

  // Private helper methods
  static Widget _buildDefaultServiceLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: AppDimensions.iconSizeM,
            height: AppDimensions.iconSizeM,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Laddar recept...',
            style: AppTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }

  static Widget _buildDefaultServiceError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingL),
        child: Container(
          padding: EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Text(
            error,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  static Widget _buildLoadingOverlay() {
    return Container(
      color: AppColors.neutralDark.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          ),
          child: SizedBox(
            width: AppDimensions.iconSizeM,
            height: AppDimensions.iconSizeM,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
        ),
      ),
    );
  }
}

/// Consumer widget för att lyssna på UnifiedRecipeService
class _RecipeServiceConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    dynamic value,
    Widget? child,
  ) builder;

  const _RecipeServiceConsumer({required this.builder});

  @override
  Widget build(BuildContext context) {
    final recipeService = sl<UnifiedRecipeService>();
    return ListenableBuilder(
      listenable: recipeService,
      builder: (context, _) {
        return builder(context, recipeService, null);
      },
    );
  }
}