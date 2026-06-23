import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/widgets/common/routing/deferred_route_loader.dart';

/// Builder for creating routes that load deferred modules
class AsyncRouteBuilder {
  /// Build a route that loads a deferred module before displaying content
  static Route<dynamic> buildDeferredRoute({
    required String routeName,
    required RouteSettings settings,
    required String moduleName,
    required RouteAnimationType animationType,
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) {
        return DeferredRouteLoader(
          moduleName: moduleName,
          routeName: routeName,
          settings: settings,
        );
      },
      transitionsBuilder: _getTransitionsBuilder(animationType),
      transitionDuration: _getTransitionDuration(animationType),
    );
  }

  /// Get the appropriate transition builder for the animation type
  /// Respects reduced motion accessibility preference (WCAG 2.3.3)
  static Widget Function(
    BuildContext,
    Animation<double>,
    Animation<double>,
    Widget,
  )
  _getTransitionsBuilder(RouteAnimationType animationType) {
    switch (animationType) {
      case RouteAnimationType.fade:
        return (context, animation, secondaryAnimation, child) {
          // Skip animation when reduced motion is enabled
          if (!AnimationUtils.shouldAnimate(context)) return child;
          return FadeTransition(opacity: animation, child: child);
        };

      case RouteAnimationType.slideFromBottom:
        return (context, animation, secondaryAnimation, child) {
          if (!AnimationUtils.shouldAnimate(context)) return child;
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        };

      case RouteAnimationType.slideFromRight:
        return (context, animation, secondaryAnimation, child) {
          if (!AnimationUtils.shouldAnimate(context)) return child;
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        };

      case RouteAnimationType.scale:
        return (context, animation, secondaryAnimation, child) {
          if (!AnimationUtils.shouldAnimate(context)) return child;
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.elasticOut;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final scaleAnimation = animation.drive(tween);
          return ScaleTransition(scale: scaleAnimation, child: child);
        };
    }
  }

  /// Get the transition duration for the animation type
  static Duration _getTransitionDuration(RouteAnimationType animationType) {
    switch (animationType) {
      case RouteAnimationType.fade:
        return const Duration(milliseconds: 300);
      case RouteAnimationType.slideFromBottom:
        return const Duration(milliseconds: 400);
      case RouteAnimationType.slideFromRight:
        return const Duration(milliseconds: 300);
      case RouteAnimationType.scale:
        return const Duration(milliseconds: 600);
    }
  }
}
