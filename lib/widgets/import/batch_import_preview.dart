import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/unread_line_detector.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Preview screen for batch file import.
/// Shows parsed recipes as a selectable checklist before saving.
///
/// A recipe with lines the reader could not read is never saved with the
/// batch: it would save guessed text past the review (flows-roles-budget.md,
/// BUT-2158). Its row says how many lines, and a tap opens it in the editor,
/// where the review shows them.
class BatchImportPreview extends StatefulWidget {
  final List<Recipe> recipes;

  const BatchImportPreview({super.key, required this.recipes, this.backTo});

  /// The name of the import view that opened the preview, for the back
  /// arrow's name "Tillbaka till …" (tillganglighetshandoff:132).
  final String? backTo;

  @override
  State<BatchImportPreview> createState() => _BatchImportPreviewState();
}

class _BatchImportPreviewState extends State<BatchImportPreview> {
  final Set<int> _selectedIndices = {};
  final Set<int> _openedIndices = {};
  late final List<int> _unreadCounts = [
    for (final recipe in widget.recipes)
      recipe.ingredients.where(UnreadLineDetector.isUnread).length,
  ];

  Iterable<int> get _batchIndices => Iterable<int>.generate(
    widget.recipes.length,
  ).where((i) => _unreadCounts[i] == 0);

  @override
  void initState() {
    super.initState();
    _selectedIndices.addAll(_batchIndices);
  }

  bool get _allSelected =>
      _batchIndices.isNotEmpty &&
      _selectedIndices.length == _batchIndices.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(_batchIndices);
      }
    });
  }

  Future<void> _openForReview(int index) async {
    setState(() => _openedIndices.add(index));
    await Navigator.of(context).pushNamed(
      Routes.manualEntry,
      arguments: {'initialRecipe': widget.recipes[index], 'isTemplate': true},
    );
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
      // A subpage (Komponentark v1:71-78; B-45): the back arrow and the title
      // on the canonical top bar, left-aligned as drawn (v1:73).
      appBar: ButleryTopBar.undersida(
        title: context.l10n.importPreviewTitle,
        backTo: widget.backTo,
        actions: [
          TextButton.icon(
            onPressed: _toggleAll,
            icon: ButleryIcon(
              _allSelected ? ButleryIcons.square : ButleryIcons.checkSquare,
              size: AppDimensions.iconSizeS,
            ),
            label: Text(
              _allSelected
                  ? context.l10n.importDeselectAll
                  : context.l10n.importSelectAll,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: AppDimensions.responsiveContentPadding(context),
        itemCount: widget.recipes.length,
        itemBuilder: (context, index) {
          final recipe = widget.recipes[index];
          final isSelected = _selectedIndices.contains(index);
          final unread = _unreadCounts[index];

          if (unread > 0) {
            return ListTile(
              key: ValueKey('batch-import-unread-$index'),
              onTap: () => _openForReview(index),
              title: Text(
                recipe.title,
                style: AppTextStyles.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _openedIndices.contains(index)
                    ? context.l10n.importPreviewOpenedForReview
                    : context.l10n.importPreviewUnreadLines(unread),
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const ButleryIcon(ButleryIcons.chevronRight),
            );
          }

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
            icon: const ButleryIcon(ButleryIcons.download),
            label: Text(
              context.l10n.importConfirmButton(_selectedIndices.length),
            ),
          ),
        ),
      ),
    );
  }
}
