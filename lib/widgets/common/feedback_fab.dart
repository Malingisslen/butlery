/// Floating "!" button for beta feedback, shown on every authenticated screen.
/// Captures a screenshot of the underlying page via RepaintBoundary and
/// opens the feedback form dialog.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
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

/// Square "!" button positioned at bottom-right that opens a feedback form.
/// Only visible when the user is authenticated.
class FeedbackFAB extends StatefulWidget {
  const FeedbackFAB({super.key});

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

    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        if (!authService.isAuthenticated) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;
        // Positioned high enough to clear both standard Scaffold FABs
        // (bottom: 16, 56px tall) and extended FABs at the same slot (e.g.
        // the shopping "Lägg till vara" and veckomeny "Till inköpslistan"
        // buttons). Extended FABs sit roughly at global bottom 76-132 when
        // the main shell's BottomNavigationBar (~60px) is underneath, so
        // we stack above them via the shared offset constant.
        return Positioned(
          bottom: AppDimensions.feedbackFabBottomOffset,
          right: 16,
          child: Semantics(
            label: context.l10n.feedbackSendLabel,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: Container(
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: AppShadows.card,
                ),
                child: Center(
                  child: Text(
                    '!',
                    style: AppTextStyles.headlineBold.copyWith(
                      color: cs.primary,
                      fontSize: 24,
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
      final boundary = feedbackRepaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
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
