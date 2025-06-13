// lib/utils/route_animations.dart

import 'package:flutter/material.dart';

/// Helper class för smooth navigation animations i Butlery
class RouteAnimations {
  /// Standard slide animation från höger (iOS-style)
  static Route slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Definiera start och slutposition
        const begin = Offset(1.0, 0.0); // Startar från höger
        const end = Offset.zero; // Slutar i center
        const curve = Curves.easeInOutCubic; // Smooth kurva

        // Skapa animationen
        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide animation från botten (för modals/sheets)
  static Route slideFromBottom(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0); // Startar från botten
        const end = Offset.zero;
        const curve = Curves.easeOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  /// Fade animation (för övergångar som känns "samma nivå")
  static Route fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// Scale + fade animation (för dialoger eller "pop")
  static Route scaleAndFade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Kombinera scale och fade
        const curve = Curves.easeInOut;
        var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  /// Custom animation med flera effekter samtidigt
  static Route customSlideScale(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;
        var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

        // Slide från höger
        var slideAnimation = Tween<Offset>(
          begin: const Offset(0.3, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        // Scale från 95% till 100%
        var scaleAnimation = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(curvedAnimation);

        // Fade från 0 till 1
        var fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(curvedAnimation);

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
