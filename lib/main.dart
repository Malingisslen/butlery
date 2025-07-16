// lib/main.dart
// ✅ REFAKTORISERAD: Använder AppInitializer för clean startup och AppRouter för routing

import 'package:flutter/material.dart';
import 'dart:async';
import 'core/constants/routes.dart';
import 'core/router/app_router.dart';

// Firebase Analytics (för observer)
import 'package:firebase_analytics/firebase_analytics.dart';
import 'repositories/firebase/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Removed unused share handling import

// State management
import 'package:provider/provider.dart';

// ✅ NY IMPORT: AppInitializer (ersätter 100+ rader initialization-kod)
import 'core/startup/app_initializer.dart';

// Dependency Injection
import 'core/injection.dart';

// Services
import 'services/offline_service.dart';
import 'services/analytics_service.dart';

// Removed unused model imports

// Theme
import 'theme/app_theme.dart';

// Auth view
import 'views/auth_view.dart';

// Befintliga views
import 'views/mina_recept_view.dart';

// ✅ DRAMATISKT FÖRENKLAD main() funktion - NER FRÅN 693 RADER!
// 🚀 PERFORMANCE FIX: Split initialization to prevent frame skipping
Future<void> main() async {
  // Only critical initialization before runApp to prevent UI blocking
  await AppInitializer.initializeCritical();

  // Start app immediately for faster UI
  runApp(const ButleryApp());

  // Complete remaining initialization in background
  AppInitializer.initializeBackground();
}

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
  }

  /// Väntar på att background initialization ska slutföras för att sätta upp analytics
  void _waitForBackgroundInitialization() async {
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
        debugPrint('⚠️ Analytics observer setup failed: $e');
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
                const SizedBox(height: 16),
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

/// Detta widget visas medan appen initialiseras i bakgrunden
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

  void _checkInitialization() async {
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
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon/logo
              Container(
                width: AppTheme.iconSizeHero,
                height: AppTheme.iconSizeHero,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: AppTheme.iconSizeHero,
                  color: AppTheme.neutralLight,
                ),
              ),
              AppTheme.largeGap,
              
              // Loading indicator
              const CircularProgressIndicator(),
              AppTheme.mediumGap,
              
              // Loading text
              Text(
                'Startar Butlery...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textTertiary,
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

/// Detta är den centrala punkten för autentiseringsflödet:
/// - Om användare är inloggad → MinaReceptView  
/// - Om användare är utloggad → AuthView
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
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  AppTheme.mediumGap,
                  Text(
                    'Kontrollerar inloggning...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textTertiary,
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
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppTheme.errorIcon(context),
                  AppTheme.mediumGap,
                  Text('Ett fel uppstod', style: AppTheme.sectionTitleStyle),
                  AppTheme.smallGap,
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle,
                  ),
                  AppTheme.mediumGap,
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