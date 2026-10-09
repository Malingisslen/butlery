/// Floating "!" button for beta feedback, shown on every authenticated screen.
/// Captures a screenshot of the underlying page via RepaintBoundary and
/// opens the feedback form dialog.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/observers/feedback_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/feedback_form_dialog.dart';

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

/// Square "!" button positioned at bottom-right that opens a feedback form.
/// Only visible when the user is authenticated, and hidden while a snackbar,
/// dialog or sheet is up and in cooking mode (produktregler.md § 18.1).
class FeedbackFAB extends StatefulWidget {
  const FeedbackFAB({super.key, this.routeObserver});

  /// Defaults to the observer registered on the app's navigator.
  final FeedbackRouteObserver? routeObserver;

  @override
  State<FeedbackFAB> createState() => _FeedbackFABState();
}

class _FeedbackFABState extends State<FeedbackFAB> {
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.tryGet<AuthService>();
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
          return const SizedBox.shrink();
        }
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
        return Positioned(
          bottom: AppDimensions.feedbackFabBottomOffset,
          right: 16,
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              // The button sits beside the Navigator, above every page's
              // Material, so without its own the "!" inherits the framework's
              // fallback text style and its yellow double underline.
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: AppDimensions.minTouchTarget,
                  height: AppDimensions.minTouchTarget,
                  // Skarmar v12 etapp 9 #fbknapp: paper with a hairline edge,
                  // so the square still reads where it meets the page colour.
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: AppShadows.card,
                  ),
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
        );
      },
    );
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
