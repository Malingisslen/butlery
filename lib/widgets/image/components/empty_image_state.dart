import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: cs.outlineVariant
              .withValues(alpha: AppDimensions.opacityMediumLight),
          style: BorderStyle.solid,
        ),
        color: cs.surfaceContainerHighest,
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: context.l10n.a11yEmptyImageStateAdd,
          button: true,
          enabled: !isLoading,
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
      ),
    );
  }

  List<Widget> _buildLoadingContent() {
    return [
      Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return LoadingIndicator(
          size: AppDimensions.iconSizeXl,
          strokeWidth: 2,
          color: cs.primary,
        );
      }),
      const SizedBox(height: AppDimensions.spacingSm),
      Builder(
        builder: (context) => Text(
          context.l10n.imageAddingImage,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: AppDimensions.opacityDark),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIdleContent() {
    return [
      Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: AppDimensions.iconSizeXl,
            color: cs.primary,
          ),
        );
      }),
      const SizedBox(height: AppDimensions.spacingSm),
      Builder(
        builder: (context) => Text(
          context.l10n.imageAddImages,
          style: AppTextStyles.contentLabel,
        ),
      ),
      const SizedBox(height: AppDimensions.spacingXxs),
      Builder(
        builder: (context) => Text(
          context.l10n.imageTapToAddUpTo(maxImages),
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: AppDimensions.opacityDark),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }
}
