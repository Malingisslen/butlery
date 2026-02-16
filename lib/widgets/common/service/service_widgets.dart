// lib/widgets/common/service/service_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// ServiceWidgets - Service integration widgets
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

  /// Generic service widget for other services
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
          Builder(
            builder: (context) => SizedBox(
              width: AppDimensions.iconSizeM,
              height: AppDimensions.iconSizeM,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Builder(
            builder: (context) => Text(
              context.l10n.loadingRecipes,
              style: AppTextStyles.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDefaultServiceError(BuildContext context, String error) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
                color: cs.error
                    .withValues(alpha: AppDimensions.opacityMediumLight)),
          ),
          child: Text(
            error,
            style: AppTextStyles.bodyMediumError,
          ),
        ),
      ),
    );
  }

  static Widget _buildLoadingOverlay() {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return ColoredBox(
          color:
              cs.onSurface.withValues(alpha: AppDimensions.opacityMediumLight),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusL),
              ),
              child: SizedBox(
                width: AppDimensions.iconSizeM,
                height: AppDimensions.iconSizeM,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Consumer widget for listening to UnifiedRecipeService
class _RecipeServiceConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    dynamic value,
    Widget? child,
  ) builder;

  const _RecipeServiceConsumer({required this.builder});

  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    return ListenableBuilder(
      listenable: recipeService,
      builder: (context, _) {
        return builder(context, recipeService, null);
      },
    );
  }
}
