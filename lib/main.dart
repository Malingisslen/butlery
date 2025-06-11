// lib/main.dart

import 'package:flutter/material.dart';

// Firebase-kärna + Firestore + Auth
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Dependency Injection
import 'core/injection.dart';
import 'services/recipe_service.dart';

import 'models/recipe.dart';
import 'theme/app_theme.dart';

// Auth view
import 'views/auth_view.dart';

// Dina vyer (svenska namn)
import 'views/mina_recept_view.dart';
import 'views/lagg_till_recept_view.dart';
import 'views/skriv_sjalv_recept_view.dart';
import 'views/fran_sociala_medier_view.dart';
import 'views/recipe_detail_view.dart';
import 'views/edit_recipe_view.dart';
import 'views/veckomeny_view.dart' as vecko;
import 'views/inkopslista_view.dart' as inkop;
import 'views/importera_fran_arkiv_view.dart';
import 'views/photo_import_view.dart';
import 'views/import_via_url_view.dart';

Future<void> main() async {
  // 1️⃣ Säkerställ att Flutter-bindningar är klara
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Initiera Firebase - MED KONTROLL för dubbel-initiering
  try {
    // Kontrollera om Firebase redan är initierad
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initierad för första gången');
    } else {
      debugPrint('✅ Firebase redan initierad, hoppar över');
    }

    // 3️⃣ Firestore ping - bara om vi har en autentiserad användare
    // Detta förhindrar permission errors vid start
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final doc = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('connection_tests')
            .doc('ping');
        await doc.set({'checkedAt': FieldValue.serverTimestamp()});
        final snapshot = await doc.get();
        if (snapshot.exists) {
          debugPrint(
            '✅ Firestore-ping lyckades för användare: ${currentUser.email}',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Firestore-ping misslyckades (kan vara permissions): $e');
      }
    } else {
      debugPrint('ℹ️ Ingen användare inloggad, hoppar över Firestore-ping');
    }
  } catch (e, st) {
    debugPrint('❌ Firebase-fel: $e\n$st');
    // Fortsätt ändå - låt appen köra med begränsad funktionalitet
  }

  // 4️⃣ ✅ Initiera Dependency Injection
  try {
    await initializeDependencies();
    debugPrint('✅ Dependency Injection initierad');

    // Testa att RecipeService skapas och fungerar
    sl<RecipeService>();
    debugPrint('✅ RecipeService hämtad från DI');
  } catch (e) {
    debugPrint('❌ Fel vid init av DI: $e');
  }

  runApp(const ButleryApp());
}

class ButleryApp extends StatelessWidget {
  const ButleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // Använd inte initialRoute, vi hanterar detta med AuthWrapper
      home: const AuthWrapper(),
      onUnknownRoute: (settings) => _errorRoute(settings.name),
      onGenerateRoute: (settings) {
        try {
          switch (settings.name) {
            case '/':
              return _route(const AuthWrapper(), settings);

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

            case '/skrivSjalv':
              final recipe = settings.arguments as Recipe?;
              return _route(
                SkrivSjalvReceptView(initialRecipe: recipe),
                settings,
              );

            case '/franSocialaMedier':
              final text = settings.arguments as String?;
              return _route(FranSocialaMedierView(initialText: text), settings);

            case '/importFranArkiv':
              return _route(const ImporteraFranArkivView(), settings);

            case '/veckomeny':
              return _route(const vecko.VeckomenyView(), settings);

            case '/inkopslista':
              return _route(const inkop.InkopslistaView(), settings);

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

            default:
              return _errorRoute('Okänd rutt: ${settings.name}');
          }
        } catch (e, st) {
          debugPrint('❌ Navigation-fel för ${settings.name}: $e\n$st');
          return _errorRoute('Fel vid navigation till ${settings.name}: $e');
        }
      },
    );
  }

  MaterialPageRoute _route(Widget page, RouteSettings settings) {
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  Route _errorRoute([String? msg]) {
    return MaterialPageRoute(
      builder:
          (ctx) => Scaffold(
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
                      onPressed:
                          () => Navigator.pushNamedAndRemoveUntil(
                            ctx,
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
    );
  }
}

/// AuthWrapper lyssnar på auth state changes och visar rätt vy
///
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
