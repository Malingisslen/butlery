/// Floating "!" button for beta feedback, shown on every authenticated screen.
/// Captures a screenshot of the underlying page via RepaintBoundary and
/// opens the feedback form dialog.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/observers/feedback_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/feedback_fab_hint.dart';
import 'package:butlery/widgets/common/feedback_form_dialog.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Global key used by the MaterialApp builder to wrap content in a
/// RepaintBoundary so the FAB can capture screenshots.
final GlobalKey feedbackRepaintBoundaryKey = GlobalKey();

/// Global key for the app's root Navigator, used by FeedbackFAB to show
/// dialogs from outside the Navigator subtree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The app's snackbar messenger. It counts the snackbars it holds, shown or
/// queued, so the "!" can step aside while one is up: the button "viker för
/// snackbaren" (produktregler.md § 18.1). Otherwise a floating snackbar's
/// action, such as "Stäng", lands under it at the bottom right.
class FeedbackAwareScaffoldMessenger extends ScaffoldMessenger {
  const FeedbackAwareScaffoldMessenger({super.key, required super.child});

  /// How many snackbars the nearest such messenger holds, or null without one.
  static ValueListenable<int>? openSnackBarsOf(BuildContext context) => context
      .findAncestorStateOfType<_FeedbackAwareScaffoldMessengerState>()
      ?._openSnackBars;

  @override
  ScaffoldMessengerState createState() =>
      _FeedbackAwareScaffoldMessengerState();
}

class _FeedbackAwareScaffoldMessengerState extends ScaffoldMessengerState {
  final ValueNotifier<int> _openSnackBars = ValueNotifier<int>(0);

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final controller = super.showSnackBar(
      snackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
    _openSnackBars.value++;
    // `closed` completes however a shown snackbar leaves: timeout, action,
    // swipe, or a hide/remove call.
    controller.closed.whenComplete(() {
      if (mounted) _openSnackBars.value--;
    });
    return controller;
  }

  // The framework drops queued snackbars here without completing their
  // `closed`, so only the current one is left to count down.
  @override
  void clearSnackBars() {
    super.clearSnackBars();
    if (_openSnackBars.value > 1) _openSnackBars.value = 1;
  }

  @override
  void dispose() {
    _openSnackBars.dispose();
    super.dispose();
  }
}

/// Square "!" button, bottom-right by default and draggable to either side
/// edge, that opens a feedback form.
/// Only visible when the user is authenticated, and hidden while a snackbar,
/// dialog or sheet is up and in cooking mode (produktregler.md § 18.1).
class FeedbackFAB extends StatefulWidget {
  const FeedbackFAB({super.key, this.routeObserver});

  /// Defaults to the observer registered on the app's navigator.
  final FeedbackRouteObserver? routeObserver;

  @override
  State<FeedbackFAB> createState() => _FeedbackFABState();
}

class _FeedbackFABState extends State<FeedbackFAB>
    with SingleTickerProviderStateMixin {
  AuthService? _authService;

  // The button floats over every screen, so it cannot know what it covers:
  // the user moves it off the content instead. Only the side and the height
  // are kept, so a narrower window or a rotation cannot strand it off screen.
  static const double _edgeGap = 16;
  bool _onRight = true;
  double _bottom = AppDimensions.feedbackFabBottomOffset;
  double? _dragLeft;

  // One-off wiggle that tells the person the button can be moved, played the
  // first time it lies over text. Polling stops for good once it has played
  // or the person has moved the button themselves.
  late final AnimationController _wiggle;
  final GlobalKey _fabKey = GlobalKey();
  Timer? _hintTimer;
  bool _moveAttempted = false;

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.tryGet<AuthService>();
    _wiggle = AnimationController(
      vsync: this,
      duration: AppMotion.pulse,
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _wiggle.dispose();
    super.dispose();
  }

  bool _hintWatchStarted = false;

  // Started on the first signed-in build, not in initState: a signed-out
  // button has nothing to hint at and must not leave a timer running.
  Future<void> _startHintWatch() async {
    if (_hintWatchStarted) return;
    _hintWatchStarted = true;
    if (await feedbackFabHintShown() || !mounted) return;
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(AppMotion.pulse, (_) => _checkHint());
  }

  Future<void> _checkHint() async {
    if (_moveAttempted) {
      _hintTimer?.cancel();
      return;
    }
    final fab = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final page =
        feedbackRepaintBoundaryKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (fab == null || page == null || !fab.attached || !page.attached) return;
    if (!fab.hasSize || isReducedMotion(context)) return;
    final rect = fab.localToGlobal(Offset.zero) & fab.size;
    if (!feedbackFabCoversContent(page, rect)) return;
    _hintTimer?.cancel();
    await markFeedbackFabHintShown();
    if (mounted) _wiggle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final authService = _authService;
    if (authService == null) return const SizedBox.shrink();

    final openSnackBars = FeedbackAwareScaffoldMessenger.openSnackBarsOf(
      context,
    );
    return ListenableBuilder(
      listenable: Listenable.merge([
        authService,
        ?openSnackBars,
        (widget.routeObserver ?? appFeedbackRouteObserver).suppressed,
      ]),
      builder: (context, _) {
        if (!authService.isAuthenticated) {
          _hintTimer?.cancel();
          _hintWatchStarted = false;
          return const SizedBox.shrink();
        }
        _startHintWatch();
        if ((openSnackBars?.value ?? 0) > 0) {
          return const SizedBox.shrink();
        }
        if ((widget.routeObserver ?? appFeedbackRouteObserver)
            .suppressed
            .value) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        // Positioned high enough to clear both standard Scaffold FABs
        // (bottom: 16, 56px tall) and extended FABs at the same slot (e.g.
        // the shopping "Lägg till vara" and veckomeny "Till inköpslistan"
        // buttons).
        final dragLeft = _dragLeft;
        final maxBottom =
            MediaQuery.sizeOf(context).height - AppDimensions.minTouchTarget;
        return Positioned(
          bottom: _bottom.clamp(0.0, maxBottom < 0 ? 0.0 : maxBottom),
          left: dragLeft ?? (_onRight ? null : _edgeGap),
          right: dragLeft == null && _onRight ? _edgeGap : null,
          child: GestureDetector(
            onPanUpdate: _onDrag,
            onPanEnd: (_) => _snapToEdge(),
            onPanCancel: _snapToEdge,
            child: AnimatedBuilder(
              animation: _wiggle,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  math.sin(_wiggle.value * 4 * math.pi) *
                      8 *
                      (1 - _wiggle.value),
                  0,
                ),
                child: child,
              ),
              child: Semantics(
                // BUT-1837: `container: true` is load-bearing, not decoration.
                // Left at its default these annotations get no node of their own —
                // they travel up the ancestor chain until some node accepts them,
                // and the one that accepted them was the screen-sized root. That
                // node then owned every other control on screen as a descendant
                // and, since it is also what receives input once semantics are
                // built (main.dart enables them by default on web), a tap aimed at
                // any control opened the feedback form instead.
                container: true,
                label: context.l10n.feedbackSendLabel,
                button: true,
                // The button sits beside the Navigator, above every page's
                // Material, so it brings its own: without one the "!" inherits
                // the framework's fallback text style and its yellow double
                // underline. Skarmar v12 etapp 9 #fbknapp: paper with a hairline
                // edge, so the square still reads where it meets the page
                // colour.
                child: DecoratedBox(
                  key: _fabKey,
                  decoration: BoxDecoration(boxShadow: AppShadows.card),
                  child: Material(
                    color: cs.surface,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: ButleryControlFocus(
                      child: PressFill(
                        surface: PressSurface.base,
                        child: InkWell(
                          onTap: _onTap,
                          child: SizedBox(
                            width: AppDimensions.minTouchTarget,
                            height: AppDimensions.minTouchTarget,
                            child: Center(
                              child: Text(
                                '!',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
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
  }

  Size _stackSize() {
    final stack = context.findAncestorRenderObjectOfType<RenderStack>();
    return stack?.size ?? MediaQuery.sizeOf(context);
  }

  void _onDrag(DragUpdateDetails details) {
    _moveAttempted = true;
    final size = _stackSize();
    const box = AppDimensions.minTouchTarget;
    final left =
        _dragLeft ?? (_onRight ? size.width - _edgeGap - box : _edgeGap);
    final top = MediaQuery.paddingOf(context).top;
    setState(() {
      _dragLeft = (left + details.delta.dx).clamp(0.0, size.width - box);
      _bottom = (_bottom - details.delta.dy).clamp(
        0.0,
        size.height - box - top,
      );
    });
  }

  void _snapToEdge() {
    final left = _dragLeft;
    if (left == null) return;
    final size = _stackSize();
    setState(() {
      _onRight = left + AppDimensions.minTouchTarget / 2 > size.width / 2;
      _dragLeft = null;
    });
  }

  Future<void> _onTap() async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    Uint8List? screenshotBytes;

    // Attempt to capture screenshot via the RepaintBoundary
    try {
      final boundary =
          feedbackRepaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        screenshotBytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {
      // Screenshot capture is best-effort; proceed without it
    }

    if (!navigator.mounted) return;

    showDialog(
      context: navigator.context,
      builder: (_) => FeedbackFormDialog(screenshot: screenshotBytes),
    );
  }
}
