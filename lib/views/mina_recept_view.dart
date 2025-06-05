import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/recipe.dart';
import '../widgets/main_layout_menu.dart';

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

                    final portionsText =
                        recept.portions != null
                            ? '${recept.portions} portioner'
                            : 'okänt antal portioner';
                    final timeText =
                        recept.timeMinutes != null
                            ? '${recept.timeMinutes} min'
                            : 'okänd tid';

                    return ListTile(
                      leading:
                          recept.imageUrl != null
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  recept.imageUrl!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : const Icon(Icons.restaurant_menu),
                      title: Text(recept.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$portionsText • $timeText'),
                          if (recept.tags != null && recept.tags!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 6,
                                children:
                                    recept.tags!
                                        .map(
                                          (tag) => Chip(
                                            label: Text(tag),
                                            backgroundColor: Colors.grey[200],
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          if (recept.rating != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: List.generate(5, (i) {
                                  final rating = recept.rating ?? 0;
                                  IconData icon;
                                  if (i + 1 <= rating) {
                                    icon = Icons.star;
                                  } else if (i + 0.5 <= rating) {
                                    icon = Icons.star_half;
                                  } else {
                                    icon = Icons.star_border;
                                  }
                                  return Icon(
                                    icon,
                                    size: 16,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
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
