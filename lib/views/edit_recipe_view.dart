// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/action_button.dart';
import '../widgets/recipe_service_widget.dart';
import '../theme/app_theme.dart';

/// ✨ UPPDATERAD REDIGERA RECEPT VY MED RECIPESERVICE
class EditRecipeView extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  State<EditRecipeView> createState() => _EditRecipeViewState();
}

class _EditRecipeViewState extends State<EditRecipeView> {
  final _formKey = GlobalKey<FormState>();
  final RecipeService _recipeService = RecipeService();

  // ✅ TILLAGT: Lista för att hålla borttagna controllers
  final List<TextEditingController> _disposedControllers = [];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _portionsController;
  late final TextEditingController _timeController;
  late final TextEditingController _ratingController;
  late final TextEditingController _imageUrlController;

  final List<TextEditingController> _ingredientControllers = [];
  final List<TextEditingController> _instructionControllers = [];
  final List<TextEditingController> _tagControllers = [];

  String? _currentImageUrl;
  bool _isSaving = false;

  // Måltidstyper för redigering
  final List<String> _mealTypes = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmål',
    'Fika',
  ];
  late String _selectedMealType;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final r = widget.recipe;
    _titleController = TextEditingController(text: r.title);
    _descriptionController = TextEditingController(text: r.description);
    _portionsController = TextEditingController(
      text: r.portions?.toString() ?? '',
    );
    _timeController = TextEditingController(
      text: r.timeMinutes?.toString() ?? '',
    );
    _ratingController = TextEditingController(text: r.rating?.toString() ?? '');
    _imageUrlController = TextEditingController(text: r.imageUrl ?? '');
    _currentImageUrl = r.imageUrl;
    _selectedMealType = r.mealType;

    _imageUrlController.addListener(() {
      final url = _imageUrlController.text.trim();
      if (url != _currentImageUrl) {
        setState(() {
          _currentImageUrl = url.isEmpty ? null : url;
        });
      }
    });

    // Initiera dynamiska listor
    for (var ing in r.ingredients) {
      _ingredientControllers.add(TextEditingController(text: ing));
    }
    _ingredientControllers.add(TextEditingController());

    for (var ins in r.instructions) {
      _instructionControllers.add(TextEditingController(text: ins));
    }
    _instructionControllers.add(TextEditingController());

    for (var tag in (r.tags ?? [])) {
      _tagControllers.add(TextEditingController(text: tag));
    }
    _tagControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _portionsController.dispose();
    _timeController.dispose();
    _ratingController.dispose();
    _imageUrlController.dispose();

    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final c in _instructionControllers) {
      c.dispose();
    }
    for (final c in _tagControllers) {
      c.dispose();
    }

    // ✅ TILLAGT: Dispose även borttagna controllers
    for (final c in _disposedControllers) {
      c.dispose();
    }
    _disposedControllers.clear();

    super.dispose();
  }

  void _handleDynamicChange(
    List<TextEditingController> list,
    int index,
    String value,
  ) {
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty && index < list.length - 1) {
        // ✅ UPPDATERAT: Spara borttagen controller istället för direkt dispose
        final removedController = list.removeAt(index);
        _disposedControllers.add(removedController);
      } else if (index == list.length - 1 && trimmed.isNotEmpty) {
        list.add(TextEditingController());
      }
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = widget.recipe.copyWith(
        mealType: _selectedMealType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        portions: int.tryParse(_portionsController.text.trim()),
        timeMinutes: int.tryParse(_timeController.text.trim()),
        ingredients:
            _ingredientControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        instructions:
            _instructionControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        tags:
            _tagControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
        rating: double.tryParse(_ratingController.text.replaceAll(',', '.')),
        imageUrl:
            _imageUrlController.text.trim().isEmpty
                ? null
                : _imageUrlController.text.trim(),
      );

      // Använd RecipeService för att uppdatera
      final result = await _recipeService.updateRecipe(updated);

      if (!mounted) return;

      if (result.isSuccess) {
        // Visa framgångsmeddelande
        RecipeServiceSnackbar.showSuccess(context, result.message);
        Navigator.pop(context, true);
      } else {
        // Visa felmeddelande
        RecipeServiceSnackbar.showError(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      RecipeServiceSnackbar.showError(
        context,
        'Kunde inte spara recept: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildDynamicList(
    String label,
    List<TextEditingController> controllers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,
        ...controllers.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: c,
                    decoration: InputDecoration(hintText: '$label ${i + 1}'),
                    onChanged: (v) => _handleDynamicChange(controllers, i, v),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                if (c.text.trim().isNotEmpty || i < controllers.length - 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () {
                      setState(() {
                        // ✅ UPPDATERAT: Spara borttagen controller
                        final removedController = controllers.removeAt(i);
                        _disposedControllers.add(removedController);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redigera recept')),
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: ActionButton.primary(
          label: 'Spara ändringar',
          icon: Icons.save,
          onPressed: _isSaving ? null : _saveRecipe,
          isLoading: _isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Måltidstyp
                  DropdownButtonFormField<String>(
                    value: _selectedMealType,
                    decoration: const InputDecoration(labelText: 'Måltidstyp'),
                    items:
                        _mealTypes
                            .map(
                              (mt) =>
                                  DropdownMenuItem(value: mt, child: Text(mt)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedMealType = v!),
                  ),
                  AppTheme.mediumGap,

                  // Bildförhandsvisning
                  if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spacingMd),
                      child: ClipRRect(
                        borderRadius: AppTheme.largeRadius,
                        child: Image.network(
                          _currentImageUrl!,
                          height: AppTheme.imageHeightMedium,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (ctx, err, stack) => Container(
                                height: AppTheme.imageHeightMedium,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: Text(
                                  'Ogiltig bild-URL',
                                  style: AppTheme.subtitleStyle,
                                ),
                              ),
                        ),
                      ),
                    ),

                  // Formulärfält
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Titel får inte vara tom'
                                : null,
                  ),
                  AppTheme.mediumGap,

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Beskrivning'),
                  ),
                  AppTheme.mediumGap,

                  TextFormField(
                    controller: _portionsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Antal portioner',
                    ),
                  ),
                  AppTheme.mediumGap,

                  TextFormField(
                    controller: _timeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tid (minuter)',
                    ),
                  ),
                  AppTheme.mediumGap,

                  _buildDynamicList('Ingrediens', _ingredientControllers),
                  AppTheme.mediumGap,

                  _buildDynamicList('Instruktion', _instructionControllers),
                  AppTheme.mediumGap,

                  _buildDynamicList('Tagg', _tagControllers),
                  AppTheme.mediumGap,

                  TextFormField(
                    controller: _ratingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
                  ),
                  AppTheme.mediumGap,

                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(labelText: 'Bild-URL'),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay när RecipeService arbetar
          RecipeServiceConsumer(
            builder: (context, recipeService, child) {
              if (recipeService.isLoading && !_isSaving) {
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
    );
  }
}
