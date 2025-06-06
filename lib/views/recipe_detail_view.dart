// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../widgets/main_layout_menu.dart';
import '../theme/app_theme.dart';

class RecipeDetailView extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Recipe>>(
      valueListenable: dummyRecipesNotifier,
      builder: (context, recipes, _) {
        final recipeInList = recipes.firstWhereOrNull(
          (r) => r.id == widget.recipe.id,
        );
        final recipeToShow = recipeInList ?? widget.recipe;

        return MainLayoutMenu(
          currentIndex: null,
          body: Scaffold(
            appBar: AppBar(title: Text(recipeToShow.title)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipeToShow.imageUrl != null &&
                      recipeToShow.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        recipeToShow.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              height: 200,
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest, // ✅ Från theme
                              alignment: Alignment.center,
                              child: Text(
                                'Ogiltig bild-URL',
                                style: TextStyle(
                                  color:
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant, // ✅ Från theme
                                ),
                              ),
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Visa måltidstyp
                  Text(
                    recipeToShow.mealType,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant, // ✅ Från theme istället för Colors.grey[700]
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipeToShow.description,
                    style:
                        Theme.of(
                          context,
                        ).textTheme.bodyLarge, // ✅ Använder theme typography
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${recipeToShow.portions ?? '?'} portioner • ${recipeToShow.timeMinutes ?? '?'} min',
                    style: AppTheme.recipeMetaStyle, // ✅ Använder theme style
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children:
                        recipeToShow.tags
                            ?.map(
                              (t) => Chip(
                                label: Text(t),
                                backgroundColor:
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest, // ✅ Från theme
                                labelStyle: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurface, // ✅ Från theme
                                ),
                              ),
                            )
                            .toList() ??
                        [],
                  ),
                  const SizedBox(height: 16),
                  if (recipeToShow.rating != null)
                    Row(
                      children: List.generate(5, (i) {
                        final r = recipeToShow.rating!;
                        if (i + 1 <= r) {
                          return Icon(
                            Icons.star,
                            color: AppTheme.starColor,
                          ); // ✅ Använder theme färg
                        } else if (i + 0.5 <= r) {
                          return Icon(
                            Icons.star_half,
                            color: AppTheme.starColor,
                          ); // ✅ Använder theme färg
                        }
                        return Icon(
                          Icons.star_border,
                          color: AppTheme.starColor,
                        ); // ✅ Använder theme färg
                      }),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Ingredienser',
                    style:
                        Theme.of(context)
                            .textTheme
                            .headlineSmall, // ✅ Använder theme typography
                  ),
                  const SizedBox(height: 8),
                  ...recipeToShow.ingredients.map(
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '- $i',
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodyMedium, // ✅ Använder theme typography
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Instruktioner',
                    style:
                        Theme.of(context)
                            .textTheme
                            .headlineSmall, // ✅ Använder theme typography
                  ),
                  const SizedBox(height: 8),
                  ...recipeToShow.instructions.mapIndexed(
                    (idx, s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${idx + 1}. $s',
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodyMedium, // ✅ Använder theme typography
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Redigera recept'),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final updated = await nav.pushNamed<bool>(
                        '/redigeraRecept',
                        arguments: recipeToShow,
                      );
                      if (!mounted) return;
                      if (updated == true) {
                        nav.pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) f) sync* {
    var i = 0;
    for (final e in this) {
      yield f(i++, e);
    }
  }
}

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
