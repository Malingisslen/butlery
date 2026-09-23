// lib/views/recipe_detail/fullscreen_image_viewer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';

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

  /// Pages whose photo failed. A failed photo is retried silently when the
  /// connection returns (Komponentark v1:839).
  final Set<int> _failedPages = {};

  /// Bumped on each silent retry so the failed images are resolved anew.
  int _retryGeneration = 0;

  /// Null when no offline service is registered (no retry trigger then).
  OfflineService? _offlineService;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _offlineService = ServiceLocator.tryGet<OfflineService>();
    _offlineService?.addListener(_onConnectivityChanged);
    _wasOnline = _offlineService?.isOnline ?? true;

    // Keep navigation bar visible for back gesture
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  void _onConnectivityChanged() {
    final isOnline = _offlineService?.isOnline ?? true;
    final cameBack = isOnline && !_wasOnline;
    _wasOnline = isOnline;
    if (!cameBack || !mounted || _failedPages.isEmpty) return;
    for (final index in _failedPages) {
      final url = widget.imageUrls[index];
      CachedNetworkImageProvider(
        url,
        cacheKey: FirebaseUrlUtils.stableCacheKey(url),
      ).evict();
    }
    _failedPages.clear();
    setState(() => _retryGeneration++);
  }

  @override
  void dispose() {
    _offlineService?.removeListener(_onConnectivityChanged);
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
                          key: ValueKey(
                            'fullscreenImage.$index.$_retryGeneration',
                          ),
                          imageUrl: widget.imageUrls[index],
                          cacheKey: FirebaseUrlUtils.stableCacheKey(
                            widget.imageUrls[index],
                          ),
                          fit: BoxFit.contain,
                          memCacheWidth: cacheWidth,
                          // A still plate while the image loads, never a spinner (P4-U05).
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) {
                            _failedPages.add(index);
                            return const ImageFailedPlate();
                          },
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

/// A photo that exists but could not be loaded. Unlike a missing photo it
/// keeps its surface and explains, so the layout does not jump when the
/// network wavers (Komponentark v1:839; Skarmar v12 del 4 #receptbildfel).
/// No button is offered: the retry is silent (the drawing's own note).
class ImageFailedPlate extends StatelessWidget {
  const ImageFailedPlate({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    // surface.raised = colorScheme.surfaceContainerHighest (#E6EAD9 light,
    // #2F4437 dark, tokens.json palette paperSoft/inkRaised). The glyph and
    // the second line are text.secondary.onRaised (#5B6959 / #A9B2A0), the
    // first line text.body (#37453A / #F5F4ED), as drawn in #receptbildfel.
    final secondary = AppModeColors.textSecondaryOnRaised(brightness);
    // tillganglighetshandoff:188: role status, the text read once, the glyph
    // decorative.
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.imageCouldNotBeShown,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SizedBox(
            width: double.infinity,
            height: AppDimensions.heightXLarge,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: AppDimensions.iconSizeL,
                  color: secondary,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  l10n.imageCouldNotBeShown,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppModeColors.textBody(brightness),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  l10n.imageRetriesWhenOnline,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
