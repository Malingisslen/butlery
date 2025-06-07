// lib/views/veckomeny_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/action_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_service_widget.dart';
import '../services/menu_service.dart';
import '../theme/app_theme.dart';

/// ✨ UPPDATERAD VY MED RECIPESERVICE OCH MENY-PERSISTENCE
class VeckomenyView extends StatefulWidget {
  const VeckomenyView({super.key});

  @override
  State<VeckomenyView> createState() => _VeckomenyViewState();
}

class _VeckomenyViewState extends State<VeckomenyView> {
  final TextEditingController _promptController = TextEditingController();
  final MenuService _menuService = MenuService();
  final RecipeService _recipeService = RecipeService();

  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;
  bool _hasGeneratedMenu = false;

  @override
  void initState() {
    super.initState();
    _loadSavedMenu();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Ladda sparad meny från localStorage eller SharedPreferences
  /// För nu sparar vi bara i state, men detta förbereder för persistence
  void _loadSavedMenu() {
    // TODO: Implementera faktisk persistence med SharedPreferences
    // För nu är detta en placeholder
    setState(() {
      _menu = {};
      _hasGeneratedMenu = false;
    });
  }

  /// Spara meny för persistence
  Future<void> _saveMenu() async {
    // TODO: Implementera faktisk persistence med SharedPreferences
    // För nu är detta en placeholder
    try {
      // Simulera save operation
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meny sparad'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        RecipeServiceSnackbar.showError(
          context,
          'Kunde inte spara meny: ${e.toString()}',
        );
      }
    }
  }

  /// Genererar meny utifrån prompt med bättre error handling
  Future<void> _generateMenu() async {
    final input = _promptController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ange vad du vill ha för meny')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // Simulera lite latency för bättre UX
      await Future.delayed(const Duration(milliseconds: 300));

      // Använd RecipeService för att få alla recept
      final allRecipes = _recipeService.recipes;

      if (allRecipes.isEmpty) {
        throw Exception('Inga recept tillgängliga. Lägg till recept först.');
      }

      final generatedMenu = _menuService.generateMenuFromPrompt(
        input,
        allRecipes,
      );

      if (generatedMenu.isEmpty) {
        throw Exception(
          'Kunde inte generera meny från din begäran. Prova att vara mer specifik.',
        );
      }

      setState(() {
        _menu = generatedMenu;
        _hasGeneratedMenu = true;
      });

      // Auto-spara menyn
      await _saveMenu();

      if (mounted) {
        RecipeServiceSnackbar.showSuccess(
          context,
          'Meny genererad med ${_getTotalRecipeCount()} recept!',
        );
      }
    } catch (e) {
      if (mounted) {
        RecipeServiceSnackbar.showError(
          context,
          'Kunde inte generera meny: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Regenerera delar av menyn
  Future<void> _regenerateSection(String section) async {
    if (!_hasGeneratedMenu) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final allRecipes = _recipeService.recipes;
      final currentCount = _menu[section]?.length ?? 1;

      // Generera nya recept för denna sektion
      final newRecipes = _menuService.generateMenuFromPrompt(
        '$currentCount $section',
        allRecipes,
      );

      if (newRecipes.containsKey(section)) {
        setState(() {
          _menu[section] = newRecipes[section]!;
        });

        await _saveMenu();

        if (mounted) {
          RecipeServiceSnackbar.showSuccess(context, '$section uppdaterad!');
        }
      }
    } catch (e) {
      if (mounted) {
        RecipeServiceSnackbar.showError(
          context,
          'Kunde inte uppdatera $section: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  /// Rensa hela menyn
  void _clearMenu() {
    setState(() {
      _menu = {};
      _hasGeneratedMenu = false;
      _promptController.clear();
    });
  }

  /// Räkna totalt antal recept i menyn
  int _getTotalRecipeCount() {
    return _menu.values.fold(0, (sum, recipes) => sum + recipes.length);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 2,
      title: 'Veckomeny',
      actions: [
        // Clear menu button
        if (_hasGeneratedMenu)
          IconButton(
            icon: AppTheme.actionIcon(context, Icons.clear),
            onPressed: _clearMenu,
            tooltip: 'Rensa meny',
          ),

        // RecipeService error indicator
        RecipeServiceConsumer(
          builder: (context, recipeService, child) {
            if (recipeService.hasError) {
              return IconButton(
                icon: AppTheme.errorIcon(context),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(recipeService.lastError!),
                      action: SnackBarAction(
                        label: 'Stäng',
                        onPressed: () {
                          recipeService.clearError();
                        },
                      ),
                    ),
                  );
                },
                tooltip: 'Visa fel',
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingSm),
            child: Column(
              children: [
                // Prompt-input med förbättrad UX
                Container(
                  padding: AppTheme.cardPadding,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: AppTheme.iconSizeAction,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: AppTheme.spacingSm),
                          Text(
                            'Vad vill du ha för meny?',
                            style: AppTheme.formLabelStyle.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      AppTheme.smallGap,
                      TextField(
                        controller: _promptController,
                        enabled: !_isGenerating,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Ex: 3 middagar, 2 luncher och 1 frukost',
                          hintStyle: AppTheme.inputHintStyle,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.edit),
                          suffixIcon:
                              _promptController.text.isNotEmpty
                                  ? IconButton(
                                    icon: AppTheme.actionIcon(
                                      context,
                                      Icons.clear,
                                    ),
                                    onPressed: () {
                                      _promptController.clear();
                                      setState(() {});
                                    },
                                  )
                                  : null,
                        ),
                        onSubmitted: (_) => _generateMenu(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppTheme.spacingSmPlus),

                // Generate button med RecipeService integration
                RecipeServiceWidget(
                  builder: (recipes) {
                    final hasRecipes = recipes.isNotEmpty;

                    return ActionButton.primary(
                      label:
                          _hasGeneratedMenu
                              ? 'Generera ny meny'
                              : 'Generera meny',
                      icon: Icons.restaurant_menu,
                      onPressed:
                          hasRecipes && !_isGenerating ? _generateMenu : null,
                      isLoading: _isGenerating,
                      loadingText: 'Genererar...',
                      isExpanded: true,
                    );
                  },
                  errorBuilder: (error) {
                    return ActionButton.primary(
                      label: 'Fel: Kunde inte hämta recept',
                      icon: Icons.error,
                      onPressed: null,
                      isExpanded: true,
                    );
                  },
                ),

                AppTheme.mediumGap,

                // Visa den genererade menyn
                Expanded(
                  child: RecipeServiceWidget(
                    showLoadingOverlay: _isGenerating,
                    builder: (recipes) {
                      if (_menu.isEmpty) {
                        return EmptyState.noMenu(
                          onAction: recipes.isNotEmpty ? _generateMenu : null,
                          actionLabel:
                              recipes.isEmpty
                                  ? 'Lägg till recept först'
                                  : 'Generera meny',
                        );
                      }

                      return ListView(
                        children: [
                          // Meny-sammanfattning
                          Container(
                            padding: AppTheme.cardPadding,
                            margin: EdgeInsets.only(bottom: AppTheme.spacingMd),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              borderRadius: AppTheme.mediumRadius,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restaurant,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  size: AppTheme.iconSizeAction,
                                ),
                                SizedBox(width: AppTheme.spacingSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Din veckomeny',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      Text(
                                        '${_getTotalRecipeCount()} recept i ${_menu.length} kategorier',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ActionButton.outlined(
                                  label: 'Spara',
                                  icon: Icons.save,
                                  onPressed: _saveMenu,
                                ),
                              ],
                            ),
                          ),

                          // Meny-sektioner
                          for (final entry in _menu.entries) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppTheme.spacingSm,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: AppTheme.sectionHeaderStyle,
                                    ),
                                  ),
                                  IconButton(
                                    icon: AppTheme.actionIcon(
                                      context,
                                      Icons.refresh,
                                    ),
                                    onPressed:
                                        _isGenerating
                                            ? null
                                            : () =>
                                                _regenerateSection(entry.key),
                                    tooltip: 'Uppdatera ${entry.key}',
                                  ),
                                ],
                              ),
                            ),
                            for (final recipe in entry.value)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppTheme.spacingXs,
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

                          // Extra padding för floating button
                          SizedBox(
                            height: AppTheme.spacingXxl + AppTheme.spacingMd,
                          ),
                        ],
                      );
                    },
                    errorBuilder: (error) {
                      return Center(
                        child: Padding(
                          padding: AppTheme.screenPadding,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppTheme.errorContainer(context, error),
                              AppTheme.mediumGap,
                              ActionButton.primary(
                                label: 'Försök igen',
                                icon: Icons.refresh,
                                onPressed: () {
                                  _recipeService.clearError();
                                  _recipeService.initialize();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay för RecipeService
          RecipeServiceConsumer(
            builder: (context, recipeService, child) {
              if (recipeService.isLoading && !_isGenerating) {
                return Container(
                  color: Colors.black26,
                  child: Center(
                    child: Container(
                      padding: AppTheme.cardPadding,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: AppTheme.largeRadius,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppTheme.mediumLoadingIndicator(),
                          AppTheme.smallGap,
                          Text(
                            'Uppdaterar recept...',
                            style: AppTheme.subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),

      // Floating action button för inköpslista
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
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              )
              : null,
    );
  }
}
