import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// The tile that adds an image to the picker, shown while it has none
class ImageAddTile extends StatelessWidget {
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool isLoading;
  final int maxImages;

  const ImageAddTile({
    super.key,
    this.borderRadius,
    this.onTap,
    this.isLoading = false,
    this.maxImages = 5,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryOutlinedBox(
      paintOnly: true,
      color: cs.surfaceContainerHighest,
      borderColor: cs.outlineVariant,
      borderRadius: borderRadius,
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
          // The plate line, not a spinner. The
          // text under it says what is happening.
          return const SizedBox(
            width: AppDimensions.iconSizeXl * 2,
            child: ExcludeSemantics(child: PlateLine()),
          );
        },
      ),
      const SizedBox(height: AppDimensions.space8),
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
          return ButleryDisc(
            color: cs.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.space12),
              child: ButleryIcon(
                ButleryIcons.camera,
                size: AppDimensions.iconSizeXl,
                color: cs.onSurface,
              ),
            ),
          );
        },
      ),
      const SizedBox(height: AppDimensions.space8),
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
