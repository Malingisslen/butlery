// lib/views/recipe_detail/fullscreen_image_viewer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Fullscreen image viewer for recipe images
/// This widget provides a full-screen image viewing experience with:
/// - Swipe navigation between images
/// - Zoom and pan functionality
/// - Image counter in the app bar
/// - Dark background for better image viewing
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Keep navigation bar visible for back gesture
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();

    // Restore system UI when leaving fullscreen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.onSurface,
      extendBodyBehindAppBar: true,
      appBar: AdaptiveAppBar(
        backgroundColor: _showAppBar
            ? cs.onSurface.withValues(alpha: AppDimensions.opacityDark)
            : Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: _showAppBar
            ? '${_currentIndex + 1} / ${widget.imageUrls.length}'
            : null,
        titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: cs.surfaceContainerHighest,
        ),
        iconTheme: IconThemeData(color: cs.surfaceContainerHighest),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.surfaceContainerHighest),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.l10n.commonBack,
        ),
      ),
      body: Builder(
        builder: (context) {
          final cacheWidth =
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          return PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return Semantics(
                label: context.l10n.a11yToggleFullscreenChrome,
                button: true,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAppBar = !_showAppBar;
                    });
                  },
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: cs.onSurface,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrls[index],
                          cacheKey: FirebaseUrlUtils.stableCacheKey(
                            widget.imageUrls[index],
                          ),
                          fit: BoxFit.contain,
                          memCacheWidth: cacheWidth,
                          placeholder: (_, __) => Center(
                            child: LoadingIndicator(
                              color: cs.surfaceContainerHighest,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              Icons.error_outline,
                              size: AppDimensions.iconSizeXxl,
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
