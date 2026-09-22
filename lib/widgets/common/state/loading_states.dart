// lib/widgets/common/state/loading_states.dart
//
// Laddning är tallrikslinje + text (produktregler.md:163 och :304, beslut
// B-18). Skelett står stilla och visas först efter 300 ms.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/state/delayed_skeleton.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/state/skeleton_components.dart';

/// LoadingStates - Loading state implementations.
///
/// Två former, inga andra: tallrikslinjen med text, och det stillastående
/// skelettet där formen är känd. Skelettet sveps i [DelayedSkeleton] så att
/// en snabb start aldrig blinkar; tallrikslinjen och texten visas direkt,
/// eftersom 300 ms-tröskeln i källan gäller skelettet och inte linjen.
class LoadingStates {
  /// Build loading state based on variant.
  ///
  /// [LoadingVariant.peaAnimation] ritar tallrikslinjen. Ärtbaljan är ingen
  /// laddningsindikator: produktregler.md:163 och :304 definierar laddning
  /// uttömmande som tallrikslinje + text, och B-18 stryker rörelse som
  /// simulerar framsteg som inte mäts. Enumvärdet står kvar tills
  /// bortstädningen (paket 7).
  static Widget buildLoadingState(
    BuildContext context, {
    required LoadingVariant? variant,
    String? message,
    int? skeletonItemCount,
  }) {
    switch (variant) {
      case LoadingVariant.skeletonRecipeList:
        return DelayedSkeleton(
          child: _buildSkeletonRecipeList(skeletonItemCount),
        );
      case LoadingVariant.skeletonRecipeCard:
        return DelayedSkeleton(child: _buildSkeletonRecipeCard());
      case LoadingVariant.skeletonGeneric:
        return DelayedSkeleton(child: _buildGenericSkeleton());
      case LoadingVariant.shimmerBox:
        return DelayedSkeleton(child: _buildShimmerBox());
      case LoadingVariant.peaAnimation:
      case LoadingVariant.spinner:
      case null:
        return _buildPlateLineLoading(context, message);
    }
  }

  /// Tallrikslinje + text. Beslut B-18: ingen snurra, ingen shimmer.
  ///
  /// Texten ar inte dekor. Regeln ar "tallrikslinje + text", och texten ska
  /// saga VAD som hamtas - en linje utan ord sager bara att appen ar upptagen.
  ///
  /// Linjen bär texten som sitt tillgängliga namn (tillganglighetshandoff:179,
  /// "etikett = vad som laddas"), så den synliga texten döljs för
  /// skärmläsaren och läses inte två gånger.
  static Widget _buildPlateLineLoading(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: PlateLine(semanticLabel: message),
              ),
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                ExcludeSemantics(
                  child: Text(
                    message,
                    style: AppTextStyles.titleMedium,
                    textAlign: TextAlign.center,
                  ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          child: Row(
            children: [
              // Bild skeleton
              SkeletonComponents.skeletonBox(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadiusS,
                ),
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
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingXs,
                      ),
                    ),
                    // Beskrivning rad 1
                    SkeletonComponents.skeletonBox(
                      height: 14,
                      width: double.infinity,
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingXs,
                      ),
                    ),
                    // Beskrivning rad 2
                    SkeletonComponents.skeletonBox(
                      height: 14,
                      width: 150,
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingXs,
                      ),
                    ),
                    // Taggar
                    Row(
                      children: [
                        SkeletonComponents.skeletonBox(
                          height: 24,
                          width: 60,
                          borderRadius: BorderRadius.zero,
                          margin: const EdgeInsetsDirectional.only(
                            end: AppDimensions.spacingXs,
                          ),
                        ),
                        SkeletonComponents.skeletonBox(
                          height: 24,
                          width: 80,
                          borderRadius: BorderRadius.zero,
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
