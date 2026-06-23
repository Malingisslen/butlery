import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';

/// Preview screen for batch file import.
/// Shows parsed recipes as a selectable checklist before saving.
class BatchImportPreview extends StatefulWidget {
  final List<Recipe> recipes;

  const BatchImportPreview({super.key, required this.recipes});

  @override
  State<BatchImportPreview> createState() => _BatchImportPreviewState();
}

class _BatchImportPreviewState extends State<BatchImportPreview> {
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _selectedIndices.addAll(Iterable<int>.generate(widget.recipes.length));
  }

  bool get _allSelected => _selectedIndices.length == widget.recipes.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(Iterable<int>.generate(widget.recipes.length));
      }
    });
  }

  void _toggle(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _confirm() {
    final selected = _selectedIndices.toList()..sort();
    final recipes = selected.map((i) => widget.recipes[i]).toList();
    Navigator.pop(context, recipes);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.importPreviewTitle,
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _toggleAll,
            icon: Icon(
              _allSelected ? Icons.deselect : Icons.select_all,
              size: AppDimensions.iconSizeS,
            ),
            label: Text(_allSelected
                ? context.l10n.importDeselectAll
                : context.l10n.importSelectAll),
          ),
        ],
      ),
      body: ListView.builder(
        padding: AppDimensions.responsiveContentPadding(context),
        itemCount: widget.recipes.length,
        itemBuilder: (context, index) {
          final recipe = widget.recipes[index];
          final isSelected = _selectedIndices.contains(index);

          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggle(index),
            activeColor: cs.primary,
            title: Text(
              recipe.title,
              style: AppTextStyles.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              context.l10n.importPreviewSubtitle(
                recipe.ingredients.length,
                recipe.instructions.length,
              ),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: FilledButton.icon(
            onPressed: _selectedIndices.isEmpty ? null : _confirm,
            icon: const Icon(Icons.file_download),
            label:
                Text(context.l10n.importConfirmButton(_selectedIndices.length)),
          ),
        ),
      ),
    );
  }
}
