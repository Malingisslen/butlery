// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD REDIGERA RECEPT VY
class EditRecipeView extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  State<EditRecipeView> createState() => _EditRecipeViewState();
}

class _EditRecipeViewState extends State<EditRecipeView> {
  final _formKey = GlobalKey<FormState>();

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
        list.removeAt(index).dispose();
      } else if (index == list.length - 1 && trimmed.isNotEmpty) {
        list.add(TextEditingController());
      }
    });
  }

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
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

      final recipes = dummyRecipesNotifier.value;
      final idx = recipes.indexWhere((r) => r.id == updated.id);
      if (idx != -1) recipes[idx] = updated;
      dummyRecipesNotifier.value = List.from(recipes);

      Navigator.pop(context, true);
    }
  }

  Widget _buildDynamicList(
    String label,
    List<TextEditingController> controllers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.formLabelStyle, // ✅ SEMANTISK STYLE
        ),
        AppTheme.smallGap, // ✅ SEMANTISK GAP
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
                    icon: AppTheme.actionIcon(
                      context,
                      Icons.delete,
                    ), // ✅ SEMANTISK IKON
                    onPressed: () {
                      setState(() {
                        controllers.removeAt(i).dispose();
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
        padding: AppTheme.screenPadding, // ✅ SEMANTISK PADDING
        child: ActionButton.primary(
          label: 'Spara ändringar',
          icon: Icons.save,
          onPressed: _saveRecipe,
          isExpanded: true,
        ),
      ),
      body: Padding(
        padding: AppTheme.screenPadding, // ✅ SEMANTISK PADDING
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Redigera mealType
              DropdownButtonFormField<String>(
                value: _selectedMealType,
                decoration: const InputDecoration(labelText: 'Måltidstyp'),
                items:
                    _mealTypes
                        .map(
                          (mt) => DropdownMenuItem(value: mt, child: Text(mt)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedMealType = v!),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
              // Bildförhandsvisning
              if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: AppTheme.spacingMd),
                  child: ClipRRect(
                    borderRadius: AppTheme.largeRadius, // ✅ SEMANTISK RADIUS
                    child: Image.network(
                      _currentImageUrl!,
                      height: AppTheme.imageHeightMedium, // ✅ SEMANTISK HEIGHT
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
                              style:
                                  AppTheme.subtitleStyle, // ✅ SEMANTISK STYLE
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
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Beskrivning'),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              TextFormField(
                controller: _portionsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Antal portioner'),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              TextFormField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tid (minuter)'),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              _buildDynamicList('Ingrediens', _ingredientControllers),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              _buildDynamicList('Instruktion', _instructionControllers),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              _buildDynamicList('Tagg', _tagControllers),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              TextFormField(
                controller: _ratingController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP

              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Bild-URL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
