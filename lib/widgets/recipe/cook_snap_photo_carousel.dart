/// BUT-949: a swipeable carousel for a cook snap's album of photos.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';

/// Renders a cook snap's photos as a swipeable, fixed-height carousel.
///
/// A single-photo album degrades to a plain image (no swipe affordance, no
/// counter) so legacy snaps look identical to before. Multi-photo albums get a
/// `PageView` plus a "current/total" counter badge; tapping any photo opens a
/// full-screen, pinch-zoomable viewer starting on the tapped page.
///
/// Square design language: zero-radius clips, no rounded corners.
class CookSnapPhotoCarousel extends StatefulWidget {
  const CookSnapPhotoCarousel({
    super.key,
    required this.photoUrls,
    this.height = 140,
    this.fit = BoxFit.cover,
  });

  /// Cover-first album URLs. Must be non-empty.
  final List<String> photoUrls;
  final double height;
  final BoxFit fit;

  /// Opens the full-screen, swipeable + pinch-zoomable album viewer starting
  /// on [initialIndex]. Used by callers that render their own thumbnail (e.g.
  /// the recipe-detail gallery) but want the same fullscreen experience.
  static void openFullScreen(
    BuildContext context,
    List<String> photoUrls, {
    int initialIndex = 0,
  }) {
    FullscreenImageViewer.open(
      context,
      photoUrls,
      initialIndex: initialIndex,
    );
  }

  @override
  State<CookSnapPhotoCarousel> createState() => _CookSnapPhotoCarouselState();
}

class _CookSnapPhotoCarouselState extends State<CookSnapPhotoCarousel> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.photoUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _photo(context, urls.first, index: 0),
      );
    }

    return Semantics(
      label: context.l10n.a11yCookSnapPhotoCarousel(_index + 1, urls.length),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) =>
                  _photo(context, urls[index], index: index),
            ),
            Positioned(
              top: AppDimensions.spacingXs,
              right: AppDimensions.spacingXs,
              child: ExcludeSemantics(
                child: _CounterBadge(current: _index + 1, total: urls.length),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, String url, {required int index}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openViewer(context, index),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: FirebaseUrlUtils.stableCacheKey(url),
        fit: widget.fit,
        width: double.infinity,
        height: widget.height,
        placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
        errorWidget: (_, __, ___) => ColoredBox(
          color: cs.surfaceContainerHighest,
          child: ButleryIcon(ButleryIcons.imageOff, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    CookSnapPhotoCarousel.openFullScreen(
      context,
      widget.photoUrls,
      initialIndex: initialIndex,
    );
  }
}

/// Page counter drawn as a translucent paper tile (overlay.paperCard) with
/// ink text (B83-3).
class _CounterBadge extends StatelessWidget {
  const _CounterBadge({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingXs,
        vertical: 2,
      ),
      color: context.modeColors.overlayPaperCard,
      child: Text(
        context.l10n.cookSnapPhotoCounter(current, total),
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
