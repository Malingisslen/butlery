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
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Fullscreen image viewer for recipe images
/// This widget provides a full-screen image viewing experience with:
/// - Swipe navigation between images
/// - Zoom and pan functionality
/// - Image counter in the app bar
/// - A dark (surface.ink) frame in both modes
/// - A close X that is always on screen, also while the bar is hidden
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
    if (!mounted || _failedPages.isEmpty) return;
    if (!cameBack) {
      // Rebuild the failed plates so their second line follows the
      // connection: it promises a retry only while one is pending.
      setState(() {});
      return;
    }
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

    // The photo is framed on surface.ink in both modes (cs.primary is
    // #24382C in both schemes, tokens.json:112-115), as the chat photo viewer
    // (lib/widgets/messaging/fullscreen_image_viewer.dart). onSurface turned
    // paper in dark mode and framed the photo light (Q7-03 = A).
    final scaffold = Scaffold(
      backgroundColor: cs.primary,
      extendBodyBehindAppBar: true,
      // A modal over the photo: X with Stäng, never a back arrow
      // (Komponentark v1:57, pattern 4), as the chat photo viewer
      // (lib/widgets/messaging/fullscreen_image_viewer.dart). ButleryTopBar
      // draws its own surface; a tap on the photo still hides the bar, and
      // the X then stays on the photo on its own (Q7-03 = A).
      appBar: _showAppBar
          ? ButleryTopBar.undersida(
              leading: IconButton(
                icon: const ButleryIcon(ButleryIcons.x),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.l10n.commonClose,
              ),
              title: '${_currentIndex + 1} / ${widget.imageUrls.length}',
            )
          : null,
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
                      color: cs.primary,
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
                            // The silent retry runs only when the connection
                            // returns, so the plate promises it only while
                            // the device is offline.
                            return ImageFailedPlate(
                              retriesWhenOnline:
                                  !(_offlineService?.isOnline ?? true),
                            );
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

    // One tree whether the bar shows or not, so the page and the zoom
    // survive the toggle.
    return Stack(
      children: [
        scaffold,
        if (!_showAppBar)
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingSm),
                child: FullscreenCloseButton(),
              ),
            ),
          ),
      ],
    );
  }
}

/// The close X that stays on the photo while the top bar is hidden
/// (Q7-03 = A). A paper X (onPrimary, #F5F4ED in both schemes) on an ink
/// disc (primary, surface.ink #24382C in both schemes; tokens.json:112-115),
/// so it reads on any photo, light or dark. The button is 48 dp
/// (tokens.json touchTarget.min), its name is Stäng (commonClose), and its
/// focus ring is the ring for an ink surface: paper (tokens.json:155-160,
/// focusRing dark), round like the disc.
class FullscreenCloseButton extends StatelessWidget {
  const FullscreenCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FocusRingSurface(
      brightness: Brightness.dark,
      child: IconButton(
        key: const ValueKey('fullscreenImage.close'),
        icon: const ButleryIcon(ButleryIcons.x),
        tooltip: context.l10n.commonClose,
        onPressed: () => Navigator.of(context).pop(),
        style: IconButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.square(AppDimensions.minTouchTarget),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// A photo that exists but could not be loaded. Unlike a missing photo it
/// keeps its surface and explains, so the layout does not jump when the
/// network wavers (Komponentark v1:839; Skarmar v12 del 4 #receptbildfel).
/// No button is offered: the retry is silent (the drawing's own note).
class ImageFailedPlate extends StatelessWidget {
  const ImageFailedPlate({super.key, this.retriesWhenOnline = true});

  /// Whether the second line "Försöker igen när nätet är tillbaka" shows.
  /// The drawing's case is the network wavering (Komponentark v1:839); a
  /// failure while online gets no retry, so the line is left out then.
  final bool retriesWhenOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    // surface.raised = colorScheme.surfaceContainerHighest (#E6EAD9 light,
    // #2F4437 dark, tokens.json:108-111; Komponentark v1:839 "ytan behålls i
    // surface.raised"). Interpretation: the token wins over the drawing's
    // dark slot #24382C (Skarmar v12 del 4:887, --r04slot-834).
    // The glyph and the second line are text.secondary.onRaised (#5B6959 /
    // #A9B2A0, tokens.json:184-187); the drawing's single #5b6959 literal
    // (del 4:888,890) is kept in light and replaced by the token in dark.
    // The first line is drawn as text.bodyMuted (#37453A / #C9D3C4,
    // tokens.json:174-177; del 4:889 --r04slot-833). The generated theme has
    // no bodyMuted member yet, so it uses text.body: right in light, and in
    // dark #F5F4ED instead of the drawn #C9D3C4 (an interpretation, open
    // until bodyMuted is delivered).
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
                // Drawn at 26 px (del 4:888); iconSizeL (24) is the nearest
                // standard step.
                ButleryIcon(
                  ButleryIcons.image,
                  size: AppDimensions.iconSizeL,
                  color: secondary,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                // Both lines are drawn 12.5 px regular (del 4:889-890). No
                // 12.5/400 role exists; caption (12/400, tokens.json:413-418)
                // is the nearest role with the drawn weight.
                Text(
                  l10n.imageCouldNotBeShown,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.captionBase.copyWith(
                    color: AppModeColors.textBody(brightness),
                  ),
                ),
                if (retriesWhenOnline) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    l10n.imageRetriesWhenOnline,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.captionBase.copyWith(color: secondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
