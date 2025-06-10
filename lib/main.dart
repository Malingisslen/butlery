// lib/main.dart

import 'package:flutter/material.dart';

// Firebase-kärna + Firestore
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Dependency Injection
import 'core/injection.dart';

import 'models/recipe.dart';
import 'theme/app_theme.dart';

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

  // 2️⃣ Initiera Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initierad');

    // 3️⃣ Enkel Firestore "ping" (skriv + läs)
    final doc = FirebaseFirestore.instance
        .collection('connection_tests')
        .doc('ping');
    await doc.set({'checkedAt': FieldValue.serverTimestamp()});
    final snapshot = await doc.get();
    if (snapshot.exists) {
      debugPrint('✅ Firestore-ping lyckades');
    } else {
      debugPrint('❌ Firestore-ping: dokument saknas');
    }
  } catch (e, st) {
    debugPrint('❌ Firebase init eller ping misslyckades: $e\n$st');
    // Här kan du välja att avbryta eller fortsätta ändå
  }

  // 4️⃣ ✅ NYTT: Initiera Dependency Injection
  try {
    await initializeDependencies();
    debugPrint('✅ Dependency Injection initierad');
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
      initialRoute: '/',
      onUnknownRoute: (settings) => _errorRoute(settings.name),
      onGenerateRoute: (settings) {
        try {
          switch (settings.name) {
            case '/':
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
