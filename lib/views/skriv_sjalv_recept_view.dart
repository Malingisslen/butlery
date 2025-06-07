// lib/views/skriv_sjalv_recept_view.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/action_button.dart';
import '../widgets/recipe_service_widget.dart';
import '../theme/app_theme.dart';

/// ✨ UPPDATERAD VY MED RECIPESERVICE INTEGRATION
class SkrivSjalvReceptView extends StatefulWidget {
  final Recipe? initialRecipe;

  const SkrivSjalvReceptView({super.key, this.initialRecipe});

  @override
  State<SkrivSjalvReceptView> createState() => _SkrivSjalvReceptViewState();
}

class _SkrivSjalvReceptViewState extends State<SkrivSjalvReceptView> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final RecipeService _recipeService = RecipeService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _portionsCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _ratingCtrl;
  late TextEditingController _imageUrlCtrl;

  late List<TextEditingController> _ingredientCtrls;
  late List<TextEditingController> _instructionCtrls;
  late List<TextEditingController> _tagCtrls;

  bool _isSaving = false;

  // Möjliga måltidstyper
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
    final r = widget.initialRecipe;

    // Initiera kontroller
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _portionsCtrl = TextEditingController(text: r?.portions?.toString() ?? '');
    _timeCtrl = TextEditingController(text: r?.timeMinutes?.toString() ?? '');
    _ratingCtrl = TextEditingController(text: r?.rating?.toString() ?? '');
    _imageUrlCtrl = TextEditingController(text: r?.imageUrl ?? '');

    // Dynamiska listor: minst ett fält
    _ingredientCtrls = [
      for (var i in (r?.ingredients ?? [])) TextEditingController(text: i),
      TextEditingController(),
    ];
    _instructionCtrls = [
      for (var i in (r?.instructions ?? [])) TextEditingController(text: i),
      TextEditingController(),
    ];
    _tagCtrls = [
      for (var t in (r?.tags ?? [])) TextEditingController(text: t),
      TextEditingController(),
    ];

    // Initiera måltidstyp
    _selectedMealType = r?.mealType ?? _mealTypes.first;
  }

  @override
  void dispose() {
    for (var c in [
      _titleCtrl,
      _descCtrl,
      _portionsCtrl,
      _timeCtrl,
      _ratingCtrl,
      _imageUrlCtrl,
    ]) {
      c.dispose();
    }
    for (var c in [..._ingredientCtrls, ..._instructionCtrls, ..._tagCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleListChange(
    List<TextEditingController> list,
    int index,
    String value,
  ) {
    // Dela på Enter
    if (value.contains('\n')) {
      final parts = value.split('\n');
      final before = parts.first;
      final after = parts.sublist(1).join('\n');
      setState(() {
        list[index].text = before;
        list[index].selection = TextSelection.collapsed(offset: before.length);
        list.insert(index + 1, TextEditingController(text: after));
      });
      return;
    }
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty && index < list.length - 1) {
        list.removeAt(index).dispose();
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
      final ingredients =
          _ingredientCtrls
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      final instructions =
          _instructionCtrls
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      final tags =
          _tagCtrls
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      final newRecipe = Recipe(
        id: widget.initialRecipe?.id ?? _uuid.v4(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        portions: int.tryParse(_portionsCtrl.text.trim()),
        timeMinutes: int.tryParse(_timeCtrl.text.trim()),
        ingredients: ingredients,
        instructions: instructions,
        tags: tags,
        rating: double.tryParse(_ratingCtrl.text.trim().replaceAll(',', '.')),
        imageUrl:
            _imageUrlCtrl.text.trim().isEmpty
                ? null
                : _imageUrlCtrl.text.trim(),
        mealType: _selectedMealType,
      );

      RecipeOperationResult result;

      if (widget.initialRecipe == null) {
        // Nytt recept
        result = await _recipeService.addRecipe(newRecipe);
      } else {
        // Uppdatera befintligt recept
        result = await _recipeService.updateRecipe(newRecipe);
      }

      if (!mounted) return;

      if (result.isSuccess) {
        RecipeServiceSnackbar.showSuccess(context, result.message);
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      } else {
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

  Widget _buildDynamicList(String label, List<TextEditingController> ctrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,
        ...ctrls.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: c,
                    decoration: InputDecoration(hintText: '$label ${i + 1}'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => _handleListChange(ctrls, i, v),
                  ),
                ),
                if (ctrls.length > 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () {
                      setState(() {
                        ctrls.removeAt(i).dispose();
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
      appBar: AppBar(title: const Text('Skriv / Redigera recept')),
      body: Stack(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: AppTheme.spacingXxl + AppTheme.spacingMd,
                ),
                children: [
                  // Måltidstyp
                  DropdownButtonFormField<String>(
                    value: _selectedMealType,
                    decoration: const InputDecoration(labelText: 'Måltidstyp'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    items:
                        _mealTypes
                            .map(
                              (mt) =>
                                  DropdownMenuItem(value: mt, child: Text(mt)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedMealType = v!),
                  ),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Titel
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty ? 'Ange titel' : null,
                  ),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Beskrivning
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Beskrivning'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Portioner & Tid
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _portionsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Portioner',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: TextFormField(
                          controller: _timeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tid (min)',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Ingredienser
                  _buildDynamicList('Ingrediens', _ingredientCtrls),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Instruktioner
                  _buildDynamicList('Instruktion', _instructionCtrls),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Taggar
                  _buildDynamicList('Tagg', _tagCtrls),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Betyg
                  TextFormField(
                    controller: _ratingCtrl,
                    decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final val = double.tryParse(v.replaceAll(',', '.'));
                      return (val == null || val < 0 || val > 5)
                          ? 'Betyg måste vara mellan 0 och 5'
                          : null;
                    },
                  ),
                  SizedBox(height: AppTheme.spacingSmPlus),

                  // Bild-URL
                  TextFormField(
                    controller: _imageUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Bild-URL'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay för RecipeService
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
                            'Bearbetar recept...',
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

      // Spara-knappen
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: ActionButton.primary(
          label: 'Spara recept',
          icon: Icons.save,
          onPressed: _isSaving ? null : _saveRecipe,
          isLoading: _isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      ),
    );
  }
}
