import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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
          color: cs.outlineVariant,
          style: BorderStyle.solid,
        ),
        color: cs.surfaceContainerHighest,
      ),
      child: Material(
        color: Colors.transparent,
        // The scroll view splits the visible texts into their own nodes, so
        // merge them into the button instead of naming it a second time.
        child: MergeSemantics(
          child: Semantics(
            button: true,
            enabled: !isLoading,
            // The plate line's own live region is excluded below, because
            // its label repeats the text next to it.
            liveRegion: isLoading,
            child: InkWell(
              onTap: isLoading ? null : onTap,
              borderRadius: borderRadius,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: isLoading
                        ? _buildLoadingContent()
                        : _buildIdleContent(),
                  ),
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
      Builder(
        builder: (context) {
          // The plate line, not a spinner (Grafisk manual v6:209). The
          // text under it says what is happening.
          return const SizedBox(
            width: AppDimensions.iconSizeXl * 2,
            child: ExcludeSemantics(child: PlateLine()),
          );
        },
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Builder(
        builder: (context) => Text(
          context.l10n.imageAddingImage,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIdleContent() {
    return [
      Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface,
            ),
            child: ButleryIcon(
              ButleryIcons.camera,
              size: AppDimensions.iconSizeXl,
              color: cs.onSurface,
            ),
          );
        },
      ),
      const SizedBox(height: AppDimensions.spacingSm),
      Builder(
        builder: (context) => Text(
          context.l10n.imageAddImages,
          style: AppTextStyles.contentLabel,
        ),
      ),
      const SizedBox(height: AppDimensions.space4),
      Builder(
        builder: (context) => Text(
          context.l10n.imageTapToAddUpTo(maxImages),
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }
}
