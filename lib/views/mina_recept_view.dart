import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/recipe.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_card.dart';

class MinaReceptView extends StatefulWidget {
  const MinaReceptView({super.key});

  @override
  State<MinaReceptView> createState() => _MinaReceptViewState();
}

class _MinaReceptViewState extends State<MinaReceptView> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.toLowerCase();

    return MainLayoutMenu(
      currentIndex: 0,
      title: 'Mina recept',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Sök recept',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Recipe>>(
              valueListenable: dummyRecipesNotifier,
              builder: (context, recipeList, _) {
                final filteredRecept =
                    recipeList.where((recipe) {
                      final matchesQuery =
                          recipe.title.toLowerCase().contains(query) ||
                          recipe.description.toLowerCase().contains(query) ||
                          recipe.ingredients.any(
                            (item) => item.toLowerCase().contains(query),
                          ) ||
                          recipe.instructions.any(
                            (step) => step.toLowerCase().contains(query),
                          ) ||
                          (recipe.tags != null &&
                              recipe.tags!.any(
                                (tag) => tag.toLowerCase().contains(query),
                              ));

                      return matchesQuery ||
                          (recipe.rating != null &&
                              recipe.rating.toString().contains(query)) ||
                          (recipe.portions != null &&
                              recipe.portions.toString().contains(query)) ||
                          (recipe.timeMinutes != null &&
                              recipe.timeMinutes.toString().contains(query));
                    }).toList();

                return ListView.builder(
                  itemCount: filteredRecept.length,
                  itemBuilder: (context, index) {
                    final recept = filteredRecept[index];

                    return RecipeCard(
                      recipe: recept,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/receptDetalj',
                          arguments: recept,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
