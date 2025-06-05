// lib/views/veckomeny_view.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';

/// Vy för att generera en anpassad veckomeny baserat på användarens prompt
class VeckomenyView extends StatefulWidget {
  const VeckomenyView({super.key});

  @override
  State<VeckomenyView> createState() => _VeckomenyViewState();
}

class _VeckomenyViewState extends State<VeckomenyView> {
  final TextEditingController _promptController = TextEditingController();
  Map<String, List<Recipe>> _menu = {};

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Genererar meny utifrån prompt, t.ex. "3 middagar, två luncher och 1 frukost"
  void _generateMenu() {
    final input = _promptController.text.trim().toLowerCase();
    final allRecipes = dummyRecipesNotifier.value;
    if (input.isEmpty) {
      setState(() => _menu.clear());
      return;
    }

    // Tillgängliga måltidstyper
    final types = <String>{for (var r in allRecipes) r.mealType};
    // Svenska talord
    final word2num = <String, int>{
      'en': 1,
      'ett': 1,
      'två': 2,
      'tre': 3,
      'fyra': 4,
      'fem': 5,
      'sex': 6,
      'sju': 7,
      'åtta': 8,
      'nio': 9,
      'tio': 10,
    };
    int? parseNumber(String s) => int.tryParse(s) ?? word2num[s];

    // Dela prompt på kommatecken, 'och', '&' eller ';'
    final parts = input.split(RegExp(r'[,&;]| och | & '));
    final counts = <String, int>{};

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      // Matcha siffror eller ordade tal i början
      final match = RegExp(r'^(\d+|[a-zåäö]+)').firstMatch(part);
      if (match == null) continue;
      final raw = match.group(1)!;
      final num = parseNumber(raw) ?? 0;
      if (num <= 0) continue;

      // Resterande ord är måltidstyp
      final keyword = part.substring(raw.length).trim();
      final type = _detectType(keyword, types);
      if (type != null) {
        counts[type] = (counts[type] ?? 0) + num;
      }
    }

    // Om inga instruktioner hittas => rensa
    if (counts.isEmpty) {
      setState(() => _menu.clear());
      return;
    }

    // Slumpa recept per vald typ
    final rand = Random();
    final result = <String, List<Recipe>>{};
    counts.forEach((mealType, count) {
      final bucket =
          allRecipes.where((r) => r.mealType == mealType).toList()
            ..shuffle(rand);
      // Ta så många som önskat (eller färre om inte tillräckligt många finns)
      result[mealType] = bucket.take(min(count, bucket.length)).toList();
    });

    setState(() => _menu = result);
  }

  /// Normaliserar pluralformer och matchar mot tillgängliga typer
  String? _detectType(String input, Set<String> available) {
    final norm =
        input
            .replaceAll(RegExp(r'\d+'), '')
            .replaceAll(RegExp(r'(ar|er)$', unicode: true), '')
            .trim();
    for (var type in available) {
      final low = type.toLowerCase();
      if (low == norm || low.startsWith(norm)) return type;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veckomeny')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // ─── Prompt-input ───────────────────────────────────
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                hintText: 'Ex: 3 middagar, 2 luncher och 1 frukost',
              ),
              onSubmitted: (_) => _generateMenu(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generateMenu,
              child: const Text('Generera meny'),
            ),

            const SizedBox(height: 16),

            // ─── Visa den genererade menyn ─────────────────────
            Expanded(
              child: ListView(
                children: [
                  for (final entry in _menu.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (final recipe in entry.value)
                      ListTile(
                        leading:
                            recipe.imageUrl != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    recipe.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : null,
                        title: Text(recipe.title),
                        subtitle: Text(
                          '${recipe.portions?.toString() ?? '-'} port • '
                          '${recipe.timeMinutes?.toString() ?? '-'} min',
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/receptDetalj',
                            arguments: recipe,
                          );
                        },
                      ),
                    const Divider(),
                  ],

                  // ─── Om vi har en meny, visa knappen till inköpslistan ─
                  if (_menu.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Till inköpslista'),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/inkopslista',
                          arguments: _menu,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
