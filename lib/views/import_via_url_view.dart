// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/recipe_scraper.dart'; // Hjälparfil för JSON-LD-extraktion
import '../theme/app_theme.dart';

/// Vy för att hämta receptdata via URL och skicka vidare till klistra-in-vyn.
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
        padding: EdgeInsets.all(AppTheme.spacingMd), // ✅ 16px från theme
        child: Column(
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Klistra in recept-URL',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme
            ElevatedButton(
              onPressed: _loading ? null : _fetchPage,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(
                  double.infinity,
                  56,
                ), // ✅ Konsistent knapp-höjd
                padding: EdgeInsets.symmetric(
                  vertical: AppTheme.spacingMd,
                ), // ✅ 16px från theme
              ),
              child:
                  _loading
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onPrimary, // ✅ Theme color
                        ),
                      )
                      : const Text('Hämta text'),
            ),
            if (_error != null) ...[
              SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme
              Text(
                _error!,
                style: TextStyle(
                  color: AppTheme.errorColor, // ✅ Theme error color
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (_pageText.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme
              Text(
                'Extraherad text:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  // ✅ Theme typography
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      AppTheme.spacingMd,
                    ), // ✅ 16px från theme
                    margin: EdgeInsets.symmetric(
                      vertical: AppTheme.spacingSm,
                    ), // ✅ 8px från theme
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest, // ✅ Theme color
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ), // ✅ 8px från theme
                      border: Border.all(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.outline, // ✅ Theme color
                      ),
                    ),
                    child: Text(
                      _pageText,
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodyMedium, // ✅ Theme typography
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme
              ElevatedButton(
                onPressed: _goToPasteView,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(
                    double.infinity,
                    56,
                  ), // ✅ Konsistent knapp-höjd
                  padding: EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMd,
                  ), // ✅ 16px från theme
                ),
                child: const Text('Gå vidare till klistra-in'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
