// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../widgets/main_layout_menu.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD RECEPTDETALJ-VY
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
              padding: AppTheme.screenPadding, // ✅ SEMANTISK PADDING
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receptbild
                  if (recipeToShow.imageUrl != null &&
                      recipeToShow.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: AppTheme.largeRadius, // ✅ SEMANTISK RADIUS
                      child: Image.network(
                        recipeToShow.imageUrl!,
                        height:
                            AppTheme.imageHeightMedium, // ✅ 200px från theme
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              height:
                                  AppTheme
                                      .imageHeightMedium, // ✅ 200px från theme
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest, // ✅ Theme color
                              alignment: Alignment.center,
                              child: Text(
                                'Ogiltig bild-URL',
                                style:
                                    AppTheme.subtitleStyle, // ✅ SEMANTISK STYLE
                              ),
                            ),
                      ),
                    ),
                  AppTheme.mediumGap, // ✅ SEMANTISK GAP
                  // Måltidstyp
                  Text(
                    recipeToShow.mealType,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppTheme.smallGap, // ✅ SEMANTISK GAP
                  // Beskrivning
                  Text(
                    recipeToShow.description,
                    style:
                        Theme.of(
                          context,
                        ).textTheme.bodyLarge, // ✅ THEME TYPOGRAPHY
                  ),
                  AppTheme.mediumGap, // ✅ SEMANTISK GAP
                  // Portioner och tid
                  Text(
                    '${recipeToShow.portions ?? '?'} portioner • ${recipeToShow.timeMinutes ?? '?'} min',
                    style: AppTheme.metadataStyle, // ✅ SEMANTISK STYLE
                  ),
                  AppTheme.mediumGap, // ✅ SEMANTISK GAP
                  // Taggar
                  if (recipeToShow.tags != null &&
                      recipeToShow.tags!.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      children:
                          recipeToShow.tags!
                              .map(
                                (t) => Chip(
                                  label: Text(t),
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                  labelStyle:
                                      AppTheme
                                          .chipLabelStyle, // ✅ SEMANTISK STYLE
                                ),
                              )
                              .toList(),
                    ),
                    AppTheme.mediumGap, // ✅ SEMANTISK GAP
                  ],

                  // Betyg
                  if (recipeToShow.rating != null) ...[
                    Row(
                      children: List.generate(5, (i) {
                        final r = recipeToShow.rating!;
                        if (i + 1 <= r) {
                          return Icon(Icons.star, color: AppTheme.starColor);
                        } else if (i + 0.5 <= r) {
                          return Icon(
                            Icons.star_half,
                            color: AppTheme.starColor,
                          );
                        }
                        return Icon(
                          Icons.star_border,
                          color: AppTheme.starColor,
                        );
                      }),
                    ),
                    AppTheme.largeGap, // ✅ SEMANTISK GAP
                  ],

                  // Ingredienser
                  Text(
                    'Ingredienser',
                    style:
                        Theme.of(
                          context,
                        ).textTheme.headlineSmall, // ✅ THEME TYPOGRAPHY
                  ),
                  AppTheme.smallGap, // ✅ SEMANTISK GAP
                  ...recipeToShow.ingredients.map(
                    (i) => Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXxs,
                      ),
                      child: Text(
                        '• $i', // Byte från '- ' till '• ' för bättre typografi
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  AppTheme.largeGap, // ✅ SEMANTISK GAP
                  // Instruktioner
                  Text(
                    'Instruktioner',
                    style:
                        Theme.of(
                          context,
                        ).textTheme.headlineSmall, // ✅ THEME TYPOGRAPHY
                  ),
                  AppTheme.smallGap, // ✅ SEMANTISK GAP
                  ...recipeToShow.instructions.mapIndexed(
                    (idx, s) => Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppTheme.spacingXs,
                      ),
                      child: Text(
                        '${idx + 1}. $s',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  AppTheme.extraLargeGap, // ✅ SEMANTISK GAP
                  // Redigera-knapp
                  ElevatedButton.icon(
                    icon: AppTheme.actionIcon(
                      context,
                      Icons.edit,
                    ), // ✅ SEMANTISK IKON
                    label: const Text('Redigera recept'),
                    style:
                        AppTheme.primaryButtonStyle, // ✅ SEMANTISK BUTTON STYLE
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

// Extensions för att undvika externa dependencies
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
