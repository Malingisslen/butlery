// lib/main.dart

import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'services/recipe_service.dart';
import 'theme/app_theme.dart';

// Import views med unika alias för att undvika konflikter
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

void main() async {
  // Säkerställ att Flutter är initialiserat innan async operationer
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisera RecipeService asynkront för bättre startup
  try {
    await RecipeService().initialize();
    debugPrint('✅ RecipeService initialiserad framgångsrikt');
  } catch (e) {
    debugPrint('❌ Fel vid initialisering av RecipeService: $e');
    // Fortsätt ändå - appen kan fortfarande köras med tom data
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

      // Global error handling för navigation
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder:
              (context) => Scaffold(
                appBar: AppBar(title: const Text('Fel')),
                body: Center(
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
                        'Sidan "${settings.name}" hittades inte',
                        style: AppTheme.cardTitleStyle,
                        textAlign: TextAlign.center,
                      ),
                      AppTheme.mediumGap,
                      ElevatedButton(
                        onPressed:
                            () => Navigator.pushReplacementNamed(context, '/'),
                        child: const Text('Tillbaka till startsidan'),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },

      onGenerateRoute: (settings) {
        try {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const MinaReceptView(),
              );

            case '/laggTill':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const LaggTillReceptView(),
              );

            case '/importViaUrl':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const ImportViaUrlView(),
              );

            case '/photoImport':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const PhotoImportView(),
              );

            case '/skrivSjalv':
              final recipe = settings.arguments as Recipe?;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => SkrivSjalvReceptView(initialRecipe: recipe),
              );

            case '/franSocialaMedier':
              final text = settings.arguments as String?;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => FranSocialaMedierView(initialText: text),
              );

            case '/importFranArkiv':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const ImporteraFranArkivView(),
              );

            case '/veckomeny':
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const vecko.VeckomenyView(),
              );

            case '/inkopslista':
              // Inga argument behövs - InkopslistaView hämtar från ModalRoute
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => const inkop.InkopslistaView(),
              );

            case '/receptDetalj':
              final recipe = settings.arguments as Recipe?;
              if (recipe == null) {
                return _errorRoute('Recipe argument saknas för receptdetalj');
              }
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => RecipeDetailView(recipe: recipe),
              );

            case '/redigeraRecept':
              final recipe = settings.arguments as Recipe?;
              if (recipe == null) {
                return _errorRoute('Recipe argument saknas för redigering');
              }
              return MaterialPageRoute<bool>(
                settings: settings,
                builder: (_) => EditRecipeView(recipe: recipe),
              );

            default:
              return _errorRoute('Okänd rutt: ${settings.name}');
          }
        } catch (e, stackTrace) {
          // Logga fel för debugging
          debugPrint('❌ Navigation fel för ${settings.name}: $e');
          debugPrint('Stack trace: $stackTrace');

          return _errorRoute('Fel vid navigation till ${settings.name}: $e');
        }
      },
    );
  }

  /// Skapa error route med detaljerat felmeddelande
  Route _errorRoute([String? errorMessage]) {
    return MaterialPageRoute(
      builder:
          (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Fel'),
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            body: Padding(
              padding: AppTheme.screenPadding,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AppTheme.iconSizeEmptyState,
                      color: AppTheme.errorColor,
                    ),
                    AppTheme.mediumGap,
                    Text(
                      'Något gick fel',
                      style: AppTheme.sectionTitleStyle.copyWith(
                        color: AppTheme.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (errorMessage != null) ...[
                      AppTheme.smallGap,
                      Container(
                        padding: AppTheme.cardPadding,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: AppTheme.mediumRadius,
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Text(
                          errorMessage,
                          style: AppTheme.subtitleStyle.copyWith(
                            color: AppTheme.errorColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    AppTheme.largeGap,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Tillbaka'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cardColor,
                            foregroundColor: AppTheme.textPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              () => Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              ),
                          icon: const Icon(Icons.home),
                          label: const Text('Startsida'),
                          style: AppTheme.primaryButtonStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
