// lib/core/router/route_animations.dart

import 'package:flutter/material.dart';
import '../constants/routes.dart';
import '../../theme/app_theme.dart';

/// Centralized route animation system for the Butlery application.
///
/// Provides consistent animations following Single Responsibility Principle
/// and 100% AppTheme integration.
class RouteAnimations {
  /// Creates the appropriate route animation based on route type.
  static Route<T> createRoute<T>(Widget page, RouteSettings settings) {
    final routeName = settings.name ?? '';
    final animationType = Routes.getAnimationType(routeName);

    switch (animationType) {
      case RouteAnimationType.fade:
        return fadeRoute<T>(page, settings);
      case RouteAnimationType.slideFromBottom:
        return slideFromBottomRoute<T>(page, settings);
      case RouteAnimationType.slideFromRight:
        return slideFromRightRoute<T>(page, settings);
      case RouteAnimationType.scale:
        return scaleRoute<T>(page, settings);
    }
  }

  /// Fade transition for auth-related screens.
  static Route<T> fadeRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: AppTheme.animationDurationFast,
      reverseTransitionDuration: AppTheme.animationDurationFast,
    );
  }

  /// Slide from bottom for import/create screens.
  static Route<T> slideFromBottomRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: AppTheme.animationDurationMedium,
      reverseTransitionDuration: AppTheme.animationDurationMedium,
    );
  }

  /// Slide from right for standard navigation.
  static Route<T> slideFromRightRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: AppTheme.animationDurationMedium,
      reverseTransitionDuration: AppTheme.animationDurationMedium,
    );
  }

  /// Scale transition for error screens and modals.
  static Route<T> scaleRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const scaleCurve = Curves.easeOutBack;
        const fadeCurve = Curves.easeOut;

        final scaleAnimation = Tween(begin: 0.8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: scaleCurve));

        final fadeAnimation = Tween(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: fadeCurve));

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: AppTheme.animationDurationFast,
      reverseTransitionDuration: AppTheme.animationDurationFast,
    );
  }

  /// Creates error route with scale animation and consistent theming.
  static Route<T> createErrorRoute<T>([String? message]) {
    return PageRouteBuilder<T>(
      settings: const RouteSettings(name: '/error'),
      pageBuilder: (context, animation, secondaryAnimation) => _ErrorScreen(
        message: message,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const scaleCurve = Curves.easeOutBack;
        const fadeCurve = Curves.easeOut;

        final scaleAnimation = Tween(begin: 0.8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: scaleCurve));

        final fadeAnimation = Tween(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: fadeCurve));

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: AppTheme.animationDurationFast,
      reverseTransitionDuration: AppTheme.animationDurationFast,
    );
  }

  /// Determines animation type for route name (fallback logic).
  static RouteAnimationType getAnimationTypeForRoute(String routeName) {
    if (routeName == Routes.home || routeName == Routes.auth) {
      return RouteAnimationType.fade;
    }

    if (_isImportOrCreateRoute(routeName)) {
      return RouteAnimationType.slideFromBottom;
    }

    if (_isShoppingOrSocialRoute(routeName)) {
      return RouteAnimationType.slideFromRight;
    }

    return RouteAnimationType.slideFromRight;
  }

  static bool _isImportOrCreateRoute(String routeName) {
    return routeName.contains('import') ||
        routeName.contains('Import') ||
        routeName == Routes.skrivSjalv ||
        routeName == Routes.franSocialaMedier ||
        routeName == Routes.photoImport ||
        routeName == Routes.receiveShare ||
        routeName == Routes.laggTill;
  }

  static bool _isShoppingOrSocialRoute(String routeName) {
    return routeName.contains('unified') ||
        routeName.contains('migration') ||
        routeName.contains('shopping') ||
        routeName.startsWith('/profile') ||
        routeName.startsWith('/friends') ||
        routeName.startsWith('/shared') ||
        routeName == Routes.collaborativeShopping ||
        routeName == Routes.menuPreview ||
        routeName == Routes.createSharedShopping;
  }

  /// Returns animation mappings for debugging.
  static Map<String, String> getAnimationMappings() {
    final mappings = <String, String>{};

    for (final route in Routes.allRoutes) {
      final animationType = getAnimationTypeForRoute(route);
      mappings[route] = animationType.toString().split('.').last;
    }

    return mappings;
  }

  /// Returns recommended duration for animation type.
  static Duration getDurationForType(RouteAnimationType type) {
    switch (type) {
      case RouteAnimationType.fade:
        return AppTheme.animationDurationFast;
      case RouteAnimationType.slideFromBottom:
      case RouteAnimationType.slideFromRight:
        return AppTheme.animationDurationMedium;
      case RouteAnimationType.scale:
        return AppTheme.animationDurationFast;
    }
  }
}

/// Error screen widget used by createErrorRoute().
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fel'),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: AppTheme.cardColor,
        elevation: AppTheme.elevationMedium,
      ),
      body: Center(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppTheme.iconSizeHero,
                color: AppTheme.errorColor,
              ),
              AppTheme.mediumGap,
              Text(
                'Något gick fel',
                style: AppTheme.sectionTitleStyle.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
              if (message != null) ...[
                AppTheme.smallGap,
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTheme.subtitleStyle,
                ),
              ],
              AppTheme.largeGap,
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    Routes.home,
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.cardColor,
                  padding: AppTheme.buttonPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.largeRadius,
                  ),
                ),
                child: const Text('Startsida'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
