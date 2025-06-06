// lib/views/veckomeny_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../widgets/recipe_card.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import '../services/menu_service.dart';
import '../theme/app_theme.dart';

/// Vy för att generera en anpassad veckomeny baserat på användarens prompt
class VeckomenyView extends StatefulWidget {
  const VeckomenyView({super.key});

  @override
  State<VeckomenyView> createState() => _VeckomenyViewState();
}

class _VeckomenyViewState extends State<VeckomenyView> {
  final TextEditingController _promptController = TextEditingController();
  final MenuService _menuService = MenuService();
  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Genererar meny utifrån prompt (nu använder MenuService)
  void _generateMenu() async {
    final input = _promptController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    // Simulera lite latency för bättre UX
    await Future.delayed(const Duration(milliseconds: 300));

    final allRecipes = dummyRecipesNotifier.value;
    final generatedMenu = _menuService.generateMenuFromPrompt(
      input,
      allRecipes,
    );

    setState(() {
      _menu = generatedMenu;
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 2,
      title: 'Veckomeny',
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacingSm), // ✅ 8px från theme
        child: Column(
          children: [
            // ─── Prompt-input ───────────────────────────────────
            TextField(
              controller: _promptController,
              enabled: !_isGenerating,
              decoration: const InputDecoration(
                hintText: 'Ex: 3 middagar, 2 luncher och 1 frukost',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              onSubmitted: (_) => _generateMenu(),
            ),
            SizedBox(height: AppTheme.spacingSm + 4), // ✅ 12px från theme
            ActionButton.primary(
              label: 'Generera meny',
              icon: Icons.restaurant_menu,
              onPressed: _generateMenu,
              isLoading: _isGenerating,
              loadingText: 'Genererar...',
              isExpanded: true,
            ),

            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme
            // ─── Visa den genererade menyn (scrollable) ─────────────────────
            Expanded(
              child:
                  _menu.isEmpty
                      ? EmptyState.noMenu(onAction: _generateMenu)
                      : ListView(
                        children: [
                          for (final entry in _menu.entries) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppTheme.spacingSm,
                              ), // ✅ 8px från theme
                              child: Text(
                                entry.key,
                                style:
                                    AppTheme
                                        .sectionHeaderStyle, // ✅ Använder theme style
                              ),
                            ),
                            for (final recipe in entry.value)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical:
                                      AppTheme.spacingXs, // ✅ 4px från theme
                                ),
                                child: CompactRecipeCard(
                                  recipe: recipe,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/receptDetalj',
                                      arguments: recipe,
                                    );
                                  },
                                ),
                              ),
                            const Divider(),
                          ],

                          // Extra padding längst ner för att undvika floating button
                          SizedBox(
                            height: AppTheme.spacingXxl + AppTheme.spacingMd,
                          ), // ✅ 48px + 16px från theme
                        ],
                      ),
            ),
          ],
        ),
      ),

      // Använd floatingActionButton för "Till inköpslista"
      floatingActionButton:
          _menu.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/inkopslista',
                    arguments: _menu,
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Till inköpslista'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
              : null,
    );
  }
}
