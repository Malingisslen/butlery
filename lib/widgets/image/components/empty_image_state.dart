import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Empty state widget for image picker with add button
class EmptyImageState extends StatelessWidget {
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isLoading;
  final int maxImages;

  const EmptyImageState({
    super.key,
    this.borderRadius,
    this.onTap,
    this.isLoading = false,
    this.maxImages = 5,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: AppColors.divider.withValues(alpha: AppDimensions.opacityMediumLight),
          style: BorderStyle.solid,
        ),
        color: AppColors.cardWhite,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: borderRadius,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    isLoading ? _buildLoadingContent() : _buildIdleContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoadingContent() {
    return [
      const SizedBox(
        width: AppDimensions.iconSizeXl,
        height: AppDimensions.iconSizeXl,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
        ),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        'Adding image...',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDark.withValues(alpha: AppDimensions.opacityDark),
        ),
      ),
    ];
  }

  List<Widget> _buildIdleContent() {
    return [
      Container(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.forestGreen.withValues(alpha: AppDimensions.opacityVeryLight),
        ),
        child: const Icon(
          Icons.add_photo_alternate_outlined,
          size: AppDimensions.iconSizeXl,
          color: AppColors.forestGreen,
        ),
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Text(
        'Lägg till bilder',
        style: AppTextStyles.text14Medium,
      ),
      const SizedBox(height: AppDimensions.spacingXxs),
      Text(
        'Tryck för att lägga till upp till $maxImages bilder',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textDark.withValues(alpha: AppDimensions.opacityDark),
        ),
        textAlign: TextAlign.center,
      ),
    ];
  }
}
