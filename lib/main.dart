// lib/main.dart
// ✅ REFAKTORISERAD: Använder AppInitializer för clean startup

import 'package:flutter/material.dart';
import 'dart:async';
import 'core/constants/routes.dart';

// Firebase Analytics (för observer)
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Share handling
import 'package:share_handler/share_handler.dart';

// State management
import 'package:provider/provider.dart';

// ✅ NY IMPORT: AppInitializer (ersätter 100+ rader initialization-kod)
import 'core/startup/app_initializer.dart';

// Services
import 'services/offline_service.dart';
import 'services/analytics_service.dart';

// Models
import 'models/recipe.dart';
import 'models/shared_menu.dart';
import 'models/user_profile.dart';

// Theme
import 'theme/app_theme.dart';

// Auth view
import 'views/auth_view.dart';

// Befintliga views
import 'views/mina_recept_view.dart';
import 'views/lagg_till_recept_view.dart';
import 'views/skriv_sjalv_recept_view.dart';
import 'views/fran_sociala_medier_view.dart';
import 'views/recipe_detail_view.dart';
import 'views/edit_recipe_view.dart';
import 'views/veckomeny_view.dart' as vecko;
import 'views/importera_fran_arkiv_view.dart';
import 'views/photo_import_view.dart';
import 'views/import_via_url_view.dart';
import 'views/receive_share_view.dart';

// ===== UNIFIED SHOPPING SYSTEM =====
import 'views/unified_shopping_view.dart';

// Social Views
import 'views/social/user_profile_edit_view.dart';
import 'views/social/friends_list_view.dart';
import 'views/social/friend_requests_view.dart';
import 'views/social/shared_with_me_view.dart';
import 'views/social/collaborative_shopping_view.dart';
import 'views/social/menu_preview_view.dart';
import 'views/social/create_shared_shopping_list_view.dart';
import 'views/social/friend_profile_view.dart';

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

  // Stream subscription för delningar
  late StreamSubscription<SharedMedia> _shareSubscription;

  @override
  void initState() {
    super.initState();
    _waitForBackgroundInitialization();
  }

  /// Wait for background initialization to complete before setting up services
  Future<void> _waitForBackgroundInitialization() async {
    // Wait for background initialization to complete
    while (!AppInitializer.isBackgroundInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Now safe to initialize services
    _initAnalyticsObserver();
    _initShareHandler();
  }

  /// Initialize analytics observer after background initialization
  void _initAnalyticsObserver() {
    try {
      _analyticsObserver = AnalyticsService().observer ??
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
      setState(() {}); // Update UI with analytics observer
    } catch (e) {
      debugPrint('⚠️ Analytics observer initialization failed: $e');
    }
  }

  /// Initierar share handler för att ta emot delningar från andra appar
  Future<void> _initShareHandler() async {
    debugPrint('📄 Initierar share handler...');

    // Lyssna på delningar när appen är öppen
    _shareSubscription = ShareHandler.instance.sharedMediaStream.listen(
      (SharedMedia media) {
        debugPrint('📥 Mottog delning (app öppen): ${media.content}');
        _handleSharedMedia(media);
      },
      onError: (error) {
        debugPrint('❌ Share handler stream error: $error');
      },
    );

    // Hantera delning som startade appen
    try {
      final initialMedia = await ShareHandler.instance.getInitialSharedMedia();
      if (initialMedia != null) {
        debugPrint('📥 Mottog delning (app startad): ${initialMedia.content}');
        // Vänta lite så navigation är redo
        Future.delayed(AppTheme.animationDurationSlow, () {
          _handleSharedMedia(initialMedia);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Kunde inte hämta initial shared media: $e');
    }
  }

  /// Hanterar mottagen delning
  void _handleSharedMedia(SharedMedia media) {
    // Kontrollera om vi har innehåll
    if (media.content == null || media.content!.isEmpty) {
      debugPrint('⚠️ Tom delning mottagen');
      return;
    }

    // Kontrollera om användaren är inloggad
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Användare ej inloggad - kan inte hantera delning');
      return;
    }

    // Navigera till ReceiveShareView
    debugPrint(
      '🚀 Navigerar till /receiveShare med innehåll: ${media.content}',
    );
    _navigatorKey.currentState?.pushNamed(
      '/receiveShare',
      arguments: {
        'content': media.content,
        'type': 'text', // Ändrat från SharedMediaType
      },
    );
  }

  @override
  void dispose() {
    _shareSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OfflineService>.value(
      value: OfflineService(), // Singleton instance
      child: MaterialApp(
        navigatorKey: _navigatorKey, // Viktigt för global navigation
        navigatorObservers: _analyticsObserver != null ? [_analyticsObserver!] : [], // Analytics tracking (safe)
        title: 'Butlery',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // Använd inte initialRoute, vi hanterar detta med InitializationWrapper
        home: const InitializationWrapper(),
        onUnknownRoute: (settings) => _errorRoute(settings.name),
        onGenerateRoute: (settings) {
          try {
            switch (settings.name) {
              case '/':
                return _route(const InitializationWrapper(), settings);

              case '/auth':
                return _route(const AuthView(), settings);

              case '/home':
                return _route(const MinaReceptView(), settings);

              case '/laggTill':
                return _route(const LaggTillReceptView(), settings);

              case '/importViaUrl':
                return _route(const ImportViaUrlView(), settings);

              case '/photoImport':
                return _route(const PhotoImportView(), settings);

              case '/shared':
                return _route(const SharedWithMeView(), settings);

              case '/skrivSjalv':
                final recipe = settings.arguments as Recipe?;
                return _route(
                  SkrivSjalvReceptView(initialRecipe: recipe),
                  settings,
                );

              case '/franSocialaMedier':
                // UPPDATERAD! Hantera både gammal (String) och ny (Map) argumentstruktur
                String? text;
                String? sourceUrl;

                if (settings.arguments is String?) {
                  // Gammal struktur - bara text
                  text = settings.arguments as String?;
                } else if (settings.arguments is Map<String, dynamic>) {
                  // Ny struktur - Map med text och sourceUrl
                  final args = settings.arguments as Map<String, dynamic>;
                  text = args['text'] as String?;
                  sourceUrl = args['sourceUrl'] as String?;
                }

                return _route(
                  FranSocialaMedierView(
                    initialText: text,
                    sourceUrl: sourceUrl,
                  ),
                  settings,
                );

              case '/importFranArkiv':
                return _route(const ImporteraFranArkivView(), settings);

              case '/veckomeny':
                return _route(const vecko.VeckomenyView(), settings);

              // ===== UNIFIED SHOPPING SYSTEM ROUTES =====
              case '/unified-shopping':
                return _route(const UnifiedShoppingView(), settings);

              case '/inkopslista':
                return _route(const UnifiedShoppingView(), settings);
              // ===== END UNIFIED SHOPPING ROUTES =====

              case '/receptDetalj':
                final recipe = settings.arguments as Recipe?;
                if (recipe == null) {
                  return _errorRoute('Recept-argument saknas för detaljvy');
                }
                return _route(RecipeDetailView(recipe: recipe), settings);

              case '/redigeraRecept':
                final recipe = settings.arguments as Recipe?;
                if (recipe == null) {
                  return _errorRoute('Recept-argument saknas för redigering');
                }
                return MaterialPageRoute<bool>(
                  settings: settings,
                  builder: (_) => EditRecipeView(recipe: recipe),
                );

              // BEFINTLIG: Ta emot delningar
              case '/receiveShare':
                final args = settings.arguments as Map<String, dynamic>?;
                if (args == null) {
                  return _errorRoute('Delningsdata saknas');
                }
                return _route(
                  ReceiveShareView(
                    content: args['content'] as String,
                    type: args['type'] as String,
                  ),
                  settings,
                );

              // ===== SOCIAL ROUTES =====

              case '/profile/edit':
                return _route(const UserProfileEditView(), settings);

              case '/friends':
                return _route(const FriendsListView(), settings);

              case '/friends/requests':
                return _route(const FriendRequestsView(), settings);

              case '/collaborative-shopping':
                final listId = settings.arguments as String;
                return _route(
                    CollaborativeShoppingView(listId: listId), settings);

              case '/menu-preview':
                final sharedMenu = settings.arguments as SharedMenu;
                return _route(
                    MenuPreviewView(sharedMenu: sharedMenu), settings);

              case '/create-shared-shopping':
                return _route(const CreateSharedShoppingListView(), settings);

              case Routes.friendProfile: // eller '/friend-profile':
                final friend = settings.arguments as UserProfile;
                return _route(
                  FriendProfileView(friend: friend),
                  settings,
                );

              case '/shared-shopping-lists':
                return _route(
                  Scaffold(
                    appBar: AppBar(title: const Text('Delade inköpslistor')),
                    body: const Center(
                      child: Text('Delade inköpslistor kommer snart!'),
                    ),
                  ),
                  settings,
                );

              default:
                return _errorRoute('Okänd rutt: ${settings.name}');
            }
          } catch (e, st) {
            debugPrint('❌ Navigation-fel för ${settings.name}: $e\n$st');
            return _errorRoute('Fel vid navigation till ${settings.name}: $e');
          }
        },
      ),
    );
  }

  /// Helper för att skapa routes med smooth animations
  Route<dynamic> _route(Widget page, RouteSettings settings) {
    final routeName = settings.name ?? '';

    // Auth-relaterade screens får fade animation
    if (routeName == '/' || routeName == '/auth') {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppTheme.animationDurationFast,
      );
    }

    // Import/Create screens får slide från botten
    if (routeName.contains('import') ||
        routeName.contains('Import') ||
        routeName == '/skrivSjalv' ||
        routeName == '/franSocialaMedier' ||
        routeName == '/photoImport' ||
        routeName == '/receiveShare') {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppTheme.animationDurationMedium,
      );
    }

    // Unified shopping screens får slide från höger
    if (routeName.contains('unified') ||
        routeName.contains('migration') ||
        routeName.contains('shopping')) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
        transitionDuration: AppTheme.animationDurationMedium,
      );
    }

    // Social screens får slide från höger (standard)
    if (routeName.startsWith('/profile') ||
        routeName.startsWith('/friends') ||
        routeName.startsWith('/shared')) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
        transitionDuration: AppTheme.animationDurationMedium,
      );
    }

    // Standard navigation får slide från höger (iOS-style)
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: AppTheme.animationDurationMedium,
    );
  }

  /// Error route med scale + fade animation
  Route _errorRoute([String? msg]) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        appBar: AppBar(
          title: const Text('Fel'),
          backgroundColor: AppTheme.errorColor,
        ),
        body: Center(
          child: Padding(
            padding: AppTheme.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                AppTheme.mediumGap,
                Text(
                  'Något gick fel',
                  style: AppTheme.sectionTitleStyle.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
                if (msg != null) ...[
                  AppTheme.smallGap,
                  Text(msg, textAlign: TextAlign.center),
                ],
                AppTheme.largeGap,
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (_) => false,
                  ),
                  child: const Text('Startsida'),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Scale + fade för error screens
        var scaleTween = Tween(begin: 0.8, end: 1.0);
        var fadeTween = Tween(begin: 0.0, end: 1.0);
        var curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);

        return ScaleTransition(
          scale: scaleTween.animate(curve),
          child: FadeTransition(
            opacity: fadeTween.animate(curve),
            child: child,
          ),
        );
      },
      transitionDuration: AppTheme.animationDurationFast,
    );
  }
}

/// AuthWrapper lyssnar på auth state changes och visar rätt vy
///
/// InitializationWrapper - väntar på bakgrundsinitiering innan AuthWrapper visas
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
    _waitForInitialization();
  }

  Future<void> _waitForInitialization() async {
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
    if (!_isInitialized) {
      // Show loading screen while waiting for Firebase initialization
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App-ikon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: AppTheme.roundRadius,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: AppTheme.iconSizeHero,
                  color: Colors.white,
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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Medan vi väntar på auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App-ikon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: AppTheme.roundRadius,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: AppTheme.iconSizeHero,
                      color: Colors.white,
                    ),
                  ),
                  AppTheme.largeGap,
                  AppTheme.mediumLoadingIndicator(),
                  AppTheme.mediumGap,
                  Text('Laddar...', style: AppTheme.subtitleStyle),
                ],
              ),
            ),
          );
        }

        // Om fel uppstod
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Padding(
                padding: AppTheme.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppTheme.errorIcon(context),
                    AppTheme.mediumGap,
                    Text('Ett fel uppstod', style: AppTheme.sectionTitleStyle),
                    AppTheme.smallGap,
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    AppTheme.largeGap,
                    ElevatedButton(
                      onPressed: () {
                        // Försök igen genom att trigga rebuild
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Försök igen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Baserat på auth state, visa rätt vy
        if (snapshot.hasData && snapshot.data != null) {
          // Användare är inloggad
          debugPrint('✅ Användare inloggad: ${snapshot.data!.email}');
          return const MinaReceptView();
        } else {
          // Användare är utloggad
          debugPrint('❌ Ingen användare inloggad');
          return const AuthView();
        }
      },
    );
  }
}
