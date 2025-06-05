// lib/main.dart

import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'views/mina_recept_view.dart';
import 'views/lagg_till_recept_view.dart';
import 'views/skriv_sjalv_recept_view.dart';
import 'views/fran_sociala_medier_view.dart';
import 'views/recipe_detail_view.dart';
import 'views/edit_recipe_view.dart';
import 'views/veckomeny_view.dart';
import 'views/inkopslista_view.dart';
import 'views/importera_fran_arkiv_view.dart';
import 'views/photo_import_view.dart';
import 'views/import_via_url_view.dart';

void main() {
  runApp(const ButleryApp());
}

class ButleryApp extends StatelessWidget {
  const ButleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              settings: settings, // ← Lägg till det här
              builder: (_) => const MinaReceptView(),
            );

          case '/laggTill':
            return MaterialPageRoute(
              settings: settings, // ← Och här
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
              builder: (_) => const VeckomenyView(),
            );

          case '/inkopslista':
            return MaterialPageRoute(
              settings: settings, // ← Viktigt här!
              builder: (_) => const InkopslistaView(),
            );

          case '/receptDetalj':
            final recipe = settings.arguments as Recipe?;
            if (recipe != null) {
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => RecipeDetailView(recipe: recipe),
              );
            }
            return _errorRoute();

          case '/redigeraRecept':
            final recipe = settings.arguments as Recipe?;
            if (recipe != null) {
              return MaterialPageRoute<bool>(
                settings: settings,
                builder: (_) => EditRecipeView(recipe: recipe),
              );
            }
            return _errorRoute();

          default:
            return _errorRoute();
        }
      },
    );
  }

  Route _errorRoute() {
    return MaterialPageRoute(
      builder:
          (_) => const Scaffold(
            body: Center(child: Text('Fel: Vyn kunde inte laddas')),
          ),
    );
  }
}
