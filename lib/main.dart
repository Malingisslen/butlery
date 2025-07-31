/// Main entry point for the Butlery application.
///
/// This file serves as the application's bootstrap, coordinating the startup
/// sequence, dependency injection, and initial widget hierarchy. The architecture
/// follows a two-phase initialization pattern to optimize startup performance
/// and prevent UI blocking.
///
/// Key responsibilities:
/// - Critical initialization (Flutter bindings, environment variables)
/// - Background initialization (Firebase, services, dependency injection)
/// - Deep link handling for incoming shared content
/// - Authentication state management and routing
/// - Global navigation and analytics tracking
///
/// Architecture Pattern:
/// ```
/// main() -> AppInitializer.initializeCritical() -> runApp()
///   └─> AppInitializer.initializeBackground() (parallel)
///   └─> ButleryApp -> InitializationWrapper -> AuthWrapper
/// ```
///
/// Performance optimizations:
/// - Non-blocking critical initialization before runApp()
/// - Heavy services initialized in background after UI starts
/// - Analytics observer setup deferred until services are ready
/// - Cached deep link processing with proper wait states

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;

// Firebase Analytics (för observer)
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Removed unused share handling import

// State management
import 'package:provider/provider.dart';

// ✅ NY IMPORT: AppInitializer (ersätter 100+ rader initialization-kod)
import 'package:butlery/core/startup/app_initializer.dart';

// Dependency Injection
import 'package:butlery/core/injection.dart';

// Services
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:go_router/go_router.dart';

// Removed unused model imports

// Theme
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_colors.dart';

// Auth view
import 'package:butlery/views/auth_view.dart';

// Befintliga views
import 'package:butlery/views/mina_recept_view.dart';

/// Application entry point.
///
/// Implements a two-phase initialization strategy for optimal startup performance:
/// 1. Critical initialization (blocking) - Only essential components
/// 2. Background initialization (async) - Heavy services and integrations
///
/// This prevents UI blocking during startup while ensuring core functionality
/// is available immediately. The pattern reduces time-to-first-frame significantly.
Future<void> main() async {
  // Phase 1: Critical initialization - must complete before UI starts
  // Includes Flutter bindings, environment variables, and localizations
  await AppInitializer.initializeCritical();

  // Start UI immediately for best user experience
  runApp(const ButleryApp());

  // Phase 2: Background initialization - runs parallel to UI startup
  // Includes Firebase, analytics, dependency injection, and offline services
  AppInitializer.initializeBackground();
}

/// Root application widget for Butlery.
///
/// Manages the top-level application state including:
/// - Analytics observer setup after background initialization
/// - Deep link handling for shared content (recipes, menus, shopping lists)
/// - Global navigation configuration
/// - Offline service provider setup
/// - Theme configuration and route management
///
/// The widget waits for background initialization to complete before
/// setting up analytics and other non-critical services.
class ButleryApp extends StatefulWidget {
  const ButleryApp({super.key});

  @override
  State<ButleryApp> createState() => _ButleryAppState();
}

class _ButleryAppState extends State<ButleryApp> {
  // Global key för navigation
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Analytics observer för route tracking - safe fallback during initialization
  FirebaseAnalyticsObserver? _analyticsObserver;

  // Removed unused share subscription

  @override
  void initState() {
    super.initState();
    _waitForBackgroundInitialization();
    _handleInitialDeepLink();
  }

  /// Waits for background initialization to complete before setting up analytics.
  ///
  /// This ensures that all services are properly initialized before attempting
  /// to create the Firebase Analytics observer. Uses polling with a small delay
  /// to avoid blocking the UI thread.
  Future<void> _waitForBackgroundInitialization() async {
    // Warten bis background initialization fertig ist
    while (!AppInitializer.isBackgroundInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      try {
        // Setup analytics observer efter background init
        _analyticsObserver = FirebaseAnalyticsObserver(
          analytics: sl<AnalyticsService>().analytics,
        );
        setState(() {}); // Trigger rebuild with analytics
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Analytics observer setup failed: $e');
        }
      }
    }
  }

  /// Handles deep links received when the app starts.
  ///
  /// Processes incoming shared content URLs for:
  /// - Friend invitations (/invite)
  /// - Recipe sharing (/recipe)
  /// - Menu sharing (/menu)
  /// - Shopping list sharing (/shopping)
  ///
  /// Waits for background initialization to ensure all services are available
  /// before processing the deep link and navigating to appropriate views.
  Future<void> _handleInitialDeepLink() async {
    // Wait for background initialization to complete
    while (!AppInitializer.isBackgroundInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      // Get initial deep link from app launch
      final receivedIntent = await receive_intent.ReceiveIntent.getInitialIntent();
      
      if (receivedIntent != null && receivedIntent.data != null) {
        if (kDebugMode) {
          debugPrint('🔗 Initial deep link received: ${receivedIntent.data}');
        }
        await _processDeepLink(receivedIntent.data!);
      }
      
      // Note: receive_intent package doesn't support streaming
      // Deep links while app is running would typically be handled by
      // the operating system's intent system automatically
      
      if (kDebugMode) {
        debugPrint('🔗 Deep link handling initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Deep link initialization failed: $e');
      }
    }
  }

  /// Processes a deep link URL and navigates to the appropriate view.
  ///
  /// Parses the incoming URL to extract the path and query parameters,
  /// then routes to the correct handler based on the content type.
  ///
  /// [deepLinkUrl] The complete deep link URL to process
  ///
  /// Supports the following URL patterns:
  /// - `/invite?id=xxx&from=yyy&type=friend` - Friend invitations
  /// - `/recipe?id=xxx&from=yyy` - Shared recipes
  /// - `/menu?id=xxx&from=yyy` - Shared menus
  /// - `/shopping?id=xxx&from=yyy` - Shared shopping lists
  Future<void> _processDeepLink(String deepLinkUrl) async {
    try {
      final uri = Uri.parse(deepLinkUrl);
      if (kDebugMode) {
        debugPrint('🔗 Processing deep link: ${uri.path}');
      }

      // Wait for app to be ready
      if (!AppInitializer.isBackgroundInitialized) {
        if (kDebugMode) {
          debugPrint('🔗 Waiting for app initialization before processing deep link');
        }
        while (!AppInitializer.isBackgroundInitialized) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Extract path and parameters
      final path = uri.path;
      final params = uri.queryParameters;

      // Route based on deep link type
      if (path.startsWith('/invite')) {
        await _handleInvitationLink(params);
      } else if (path.startsWith('/recipe')) {
        await _handleRecipeLink(params);
      } else if (path.startsWith('/menu')) {
        await _handleMenuLink(params);
      } else if (path.startsWith('/shopping')) {
        await _handleShoppingLink(params);
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Unknown deep link path: $path');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error processing deep link: $e');
      }
    }
  }

  /// Handle friend invitation deep links
  Future<void> _handleInvitationLink(Map<String, String> params) async {
    final invitationId = params['id'];
    final fromUserId = params['from'];
    final type = params['type'];

    if (invitationId != null && fromUserId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling invitation: $type from $fromUserId');
      }
      
      // Navigate to appropriate view based on invitation type
      if (mounted && context.mounted) {
        if (type == 'friend') {
          // Navigate to friend requests view
          GoRouter.of(context).push(Routes.friendRequests);
        } else {
          // Default to friends list for unknown invitation types
          GoRouter.of(context).push(Routes.friends);
        }
      }
    }
  }

  /// Handle recipe sharing deep links
  Future<void> _handleRecipeLink(Map<String, String> params) async {
    final recipeId = params['id'];
    final fromUserId = params['from'];

    if (recipeId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling recipe link: $recipeId from $fromUserId');
      }
      
      if (mounted && context.mounted) {
        // Navigate to recipe detail view with recipe ID as query parameter
        GoRouter.of(context).push('${Routes.receptDetalj}?recipeId=$recipeId');
      }
    }
  }

  /// Handle menu sharing deep links
  Future<void> _handleMenuLink(Map<String, String> params) async {
    final menuId = params['id'];
    final fromUserId = params['from'];

    if (menuId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling menu link: $menuId from $fromUserId');
      }
      
      if (mounted && context.mounted) {
        // Navigate to shared with me view to see the menu
        GoRouter.of(context).push(Routes.shared);
      }
    }
  }

  /// Handle shopping list sharing deep links
  Future<void> _handleShoppingLink(Map<String, String> params) async {
    final listId = params['id'];
    final fromUserId = params['from'];

    if (listId != null) {
      if (kDebugMode) {
        debugPrint('🔗 Handling shopping list link: $listId from $fromUserId');
      }
      
      if (mounted && context.mounted) {
        // Navigate to collaborative shopping view
        GoRouter.of(context).push(Routes.collaborativeShopping);
      }
    }
  }


  @override
  void dispose() {
    // No share subscription to cancel anymore
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: Only access services after DI is initialized
    if (!AppInitializer.isBackgroundInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppDimensions.spacingXl),
                Text('Initialiserar tjänster...', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }
    
    return ChangeNotifierProvider<OfflineService>.value(
      value: sl<OfflineService>(), // Get from dependency injection
      child: MaterialApp(
        navigatorKey: _navigatorKey, // Viktigt för global navigation
        navigatorObservers: _analyticsObserver != null ? [_analyticsObserver!] : [], // Analytics tracking (safe)
        title: 'Butlery',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // Använd inte initialRoute, vi hanterar detta med InitializationWrapper
        home: const InitializationWrapper(),
        onUnknownRoute: AppRouter.handleUnknownRoute,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}

/// Loading screen widget displayed during background initialization.
///
/// Shows a branded loading interface while heavy services (Firebase, analytics,
/// dependency injection) are being initialized in the background. Automatically
/// transitions to the authentication wrapper once initialization completes.
///
/// The loading screen includes:
/// - App branding and logo
/// - Loading indicator
/// - Localized status text
/// - Branded color scheme
class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    // Wait for background initialization to complete
    while (!AppInitializer.isBackgroundInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.backgroundBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon/logo
              Container(
                width: AppDimensions.iconSizeHero,
                height: AppDimensions.iconSizeHero,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: AppDimensions.iconSizeHero,
                  color: AppColors.neutralLight,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXxxl),
              
              // Loading indicator
              const CircularProgressIndicator(),
              const SizedBox(height: AppDimensions.spacingXl),
              
              // Loading text
              Text(
                'Startar Butlery...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Background initialization complete - show AuthWrapper
    return const AuthWrapper();
  }
}

/// Authentication state wrapper that manages the main app flow.
///
/// Acts as the central routing point based on user authentication status:
/// - Authenticated users are directed to the main recipe view (MinaReceptView)
/// - Unauthenticated users are directed to the authentication view (AuthView)
/// - Handles loading states and error scenarios gracefully
///
/// Uses Firebase Auth's stream-based authentication state monitoring to
/// automatically react to login/logout events and update the UI accordingly.
/// Provides appropriate loading and error states with branded styling.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthRepository().authStateChanges(),
      builder: (context, snapshot) {
        // Medan vi väntar på auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.backgroundBeige,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    'Kontrollerar inloggning...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Om vi har ett fel
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.backgroundBeige,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: AppColors.error, size: AppDimensions.iconSizeXl),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text('Ett fel uppstod', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.home),
                    child: const Text('Försök igen'),
                  ),
                ],
              ),
            ),
          );
        }

        // Om användare är inloggad
        if (snapshot.hasData && snapshot.data != null) {
          return const MinaReceptView();
        }

        // Om användare är utloggad
        return const AuthView();
      },
    );
  }
}