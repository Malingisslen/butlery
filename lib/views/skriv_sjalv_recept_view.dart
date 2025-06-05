// lib/views/skriv_sjalv_recept_view.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../data/dummy_data.dart';

/// Vy för manuell inmatning eller redigering av recept.
class SkrivSjalvReceptView extends StatefulWidget {
  final Recipe? initialRecipe;

  const SkrivSjalvReceptView({super.key, this.initialRecipe});

  @override
  State<SkrivSjalvReceptView> createState() => _SkrivSjalvReceptViewState();
}

class _SkrivSjalvReceptViewState extends State<SkrivSjalvReceptView> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _portionsCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _ratingCtrl;
  late TextEditingController _imageUrlCtrl;

  late List<TextEditingController> _ingredientCtrls;
  late List<TextEditingController> _instructionCtrls;
  late List<TextEditingController> _tagCtrls;

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

  void _saveRecipe() {
    if (!_formKey.currentState!.validate()) return;

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
        _tagCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

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
          _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim(),
      mealType: _selectedMealType,
    );

    // Lägg till eller uppdatera i dummy-data, med fix för idx == -1
    final list = dummyRecipesNotifier.value;
    if (widget.initialRecipe == null) {
      // Nytt recept
      dummyRecipesNotifier.value = [...list, newRecipe];
    } else {
      final idx = list.indexWhere((r) => r.id == newRecipe.id);
      if (idx >= 0) {
        // Uppdatera befintligt
        list[idx] = newRecipe;
        dummyRecipesNotifier.value = List.from(list);
      } else {
        // Receptet fanns inte i listan (ex. hämtat via OCR/URL) → lägg till nytt
        dummyRecipesNotifier.value = [...list, newRecipe];
      }
    }

    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  Widget _buildDynamicList(String label, List<TextEditingController> ctrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...ctrls.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: c,
                    decoration: InputDecoration(hintText: '$label ${i + 1}'),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => _handleListChange(ctrls, i, v),
                  ),
                ),
                if (ctrls.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            // Lägger till extra padding längst ner så,
            // inget innehåll hamnar under knappen
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              // Måltidstyp
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
              const SizedBox(height: 12),

              // Titel
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titel'),
                textInputAction: TextInputAction.next,
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Ange titel' : null,
              ),
              const SizedBox(height: 12),

              // Beskrivning
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Beskrivning'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Portioner & Tid
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _portionsCtrl,
                      decoration: const InputDecoration(labelText: 'Portioner'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _timeCtrl,
                      decoration: const InputDecoration(labelText: 'Tid (min)'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ingredienser
              _buildDynamicList('Ingrediens', _ingredientCtrls),
              const SizedBox(height: 12),

              // Instruktioner
              _buildDynamicList('Instruktion', _instructionCtrls),
              const SizedBox(height: 12),

              // Taggar
              _buildDynamicList('Tagg', _tagCtrls),
              const SizedBox(height: 12),

              // Betyg
              TextFormField(
                controller: _ratingCtrl,
                decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
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
              const SizedBox(height: 12),

              // Bild-URL
              TextFormField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(labelText: 'Bild-URL'),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),

      // Spara-knappen ligger i bottomNavigationBar så att inget
      // klickbart innehåll täcker den.
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Spara recept'),
          onPressed: _saveRecipe,
        ),
      ),
    );
  }
}
