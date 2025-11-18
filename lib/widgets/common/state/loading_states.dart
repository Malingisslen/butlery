// lib/widgets/common/state/loading_states.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/state/skeleton_components.dart';

/// LoadingStates - Loading state implementations
/// Handles different loading variants including spinners and skeleton loaders.
class LoadingStates {
  /// Build loading state based on variant
  static Widget buildLoadingState(
    BuildContext context, {
    required LoadingVariant? variant,
    String? message,
    int? skeletonItemCount,
  }) {
    switch (variant) {
      case LoadingVariant.skeletonRecipeList:
        return _buildSkeletonRecipeList(skeletonItemCount);
      case LoadingVariant.skeletonRecipeCard:
        return _buildSkeletonRecipeCard();
      case LoadingVariant.skeletonGeneric:
        return _buildGenericSkeleton();
      case LoadingVariant.shimmerBox:
        return _buildShimmerBox();
      case LoadingVariant.spinner:
      default:
        return _buildSpinnerLoading(context, message);
    }
  }

  static Widget _buildSpinnerLoading(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  message,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSkeletonRecipeList(int? itemCount) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      itemCount: itemCount ?? 5,
      itemBuilder: (context, index) => _buildSkeletonRecipeCard(),
    );
  }

  static Widget _buildSkeletonRecipeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      child: Card(
        elevation: AppDimensions.elevationLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          child: Row(
            children: [
              // Bild skeleton
              SkeletonComponents.skeletonBox(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              // Text content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel
                    SkeletonComponents.skeletonBox(
                      height: 20,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
                    ),
                    // Beskrivning rad 1
                    SkeletonComponents.skeletonBox(
                      height: 14,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
                    ),
                    // Beskrivning rad 2
                    SkeletonComponents.skeletonBox(
                      height: 14,
                      width: 150,
                      margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
                    ),
                    // Taggar
                    Row(
                      children: [
                        SkeletonComponents.skeletonBox(
                          height: 24,
                          width: 60,
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
                          margin: const EdgeInsets.only(right: AppDimensions.spacingXs),
                        ),
                        SkeletonComponents.skeletonBox(
                          height: 24,
                          width: 80,
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusRound),
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

  static Widget _buildGenericSkeleton() {
    return Column(
      children: [
        SkeletonComponents.skeletonBox(height: 20, width: 200),
        const SizedBox(height: AppDimensions.spacingM),
        SkeletonComponents.skeletonBox(height: 14, width: 150),
        const SizedBox(height: AppDimensions.spacingM),
        SkeletonComponents.skeletonBox(height: 14, width: 100),
      ],
    );
  }

  static Widget _buildShimmerBox() {
    return SkeletonComponents.skeletonBox(
      width: 100,
      height: 100,
    );
  }
}