// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/recipe_scraper.dart'; // Hjälparfil för JSON-LD-extraktion
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD IMPORT VIA URL VY
class ImportViaUrlView extends StatefulWidget {
  const ImportViaUrlView({super.key});

  @override
  State<ImportViaUrlView> createState() => _ImportViaUrlViewState();
}

class _ImportViaUrlViewState extends State<ImportViaUrlView> {
  final _urlController = TextEditingController();
  bool _loading = false;
  String? _error;
  String _pageText = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _pageText = '';
    });

    try {
      final encodedUrl = Uri.encodeComponent(rawUrl);
      // Använder public proxy för att slippa CORS-strul
      final proxyUrl = 'https://api.allorigins.win/raw?url=$encodedUrl';
      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode != 200) {
        _error = 'Hämtning misslyckades (kod ${response.statusCode})';
      } else {
        final html = response.body;
        final recipeJson = extractRecipeFromHtml(html);

        if (recipeJson == null) {
          _error = 'Kunde inte hitta receptdata på sidan.';
        } else {
          // ───── Bygg text med ingredienser + instruktioner ─────

          final ingredients = <String>[];
          if (recipeJson['recipeIngredient'] is List) {
            ingredients.addAll(
              (recipeJson['recipeIngredient'] as List).cast<String>(),
            );
          }

          final instructions = <String>[];
          if (recipeJson['recipeInstructions'] is List) {
            for (final step in recipeJson['recipeInstructions'] as List) {
              if (step is Map<String, dynamic>) {
                // Platta ut HowToSection → itemListElement
                if (step.containsKey('itemListElement') &&
                    step['itemListElement'] is List) {
                  for (final subStep in step['itemListElement'] as List) {
                    if (subStep is Map<String, dynamic> &&
                        subStep['text'] != null) {
                      instructions.add(subStep['text'].toString());
                    }
                  }
                }
                // Om det bara är ett vanligt "text"-fält
                else if (step['text'] != null) {
                  instructions.add(step['text'].toString());
                }
              } else if (step is String) {
                instructions.add(step);
              }
            }
          }

          final buffer = StringBuffer();
          // Ingredienser
          buffer.writeln('Ingredienser:');
          for (var ingred in ingredients) {
            buffer.writeln('- $ingred');
          }
          // Instruktioner
          buffer.writeln('\nInstruktioner:');
          for (var i = 0; i < instructions.length; i++) {
            buffer.writeln('${i + 1}. ${instructions[i]}');
          }

          _pageText = buffer.toString();
        }
      }
    } catch (e) {
      _error = 'Fel vid uppkoppling: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goToPasteView() {
    if (_pageText.isEmpty) return;
    Navigator.pushNamed(context, '/franSocialaMedier', arguments: _pageText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import via URL')),
      body: Padding(
        padding: AppTheme.screenPadding, // ✅ SEMANTISK PADDING
        child: Column(
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Klistra in recept-URL',
                border: OutlineInputBorder(),
              ),
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP
            ElevatedButton(
              onPressed: _loading ? null : _fetchPage,
              style: AppTheme.primaryButtonStyle, // ✅ SEMANTISK BUTTON STYLE
              child:
                  _loading
                      ? AppTheme.smallLoadingIndicator(
                        context,
                      ) // ✅ SEMANTISK LOADING
                      : const Text('Hämta text'),
            ),

            // Error med semantisk widget ✨
            if (_error != null) ...[
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
              AppTheme.errorContainer(
                context,
                _error!,
              ), // ✅ SEMANTISK ERROR WIDGET
            ],

            if (_pageText.isNotEmpty) ...[
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
              Text(
                'Extraherad text:',
                style: AppTheme.sectionTitleStyle, // ✅ SEMANTISK STYLE
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: AppTheme.cardPadding, // ✅ SEMANTISK PADDING
                    margin: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      _pageText,
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodyMedium, // ✅ THEME TYPOGRAPHY
                    ),
                  ),
                ),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
              ElevatedButton(
                onPressed: _goToPasteView,
                style: AppTheme.primaryButtonStyle, // ✅ SEMANTISK BUTTON STYLE
                child: const Text('Gå vidare till klistra-in'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
