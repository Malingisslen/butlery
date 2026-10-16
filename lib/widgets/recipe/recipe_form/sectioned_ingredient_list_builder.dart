import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_form/ingredient_section_state.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/input/butlery_row_field.dart';

/// The sectioned ingredient editor (PR #211). Renders an ordered list of
/// component headings ("Deg", "Fyllning") and ingredient lines as a single
/// reorderable list. Headings can be added, renamed, deleted, and dragged;
/// lines can be dragged or reassigned via a non-drag "Flytta till rubrik"
/// menu (WCAG 2.1.1 — drag-only would be inaccessible).
///
/// This widget is stateless over the form's [IngredientSectionState] +
/// FormFieldsManager: it maps each [LineRow] to the next line controller in
/// order, and each [HeadingRow] to its stable-id controller. All mutations go
/// back through the callbacks (which keep the sidecar + manager in lockstep).
class SectionedIngredientListBuilder extends StatelessWidget {
  final String label;
  final List<IngredientRow> rows;
  final List<TextEditingController> lineControllers;
  final TextEditingController Function(String headingId) headingControllerFor;

  final void Function(int lineIndex, String value) onLineChanged;
  final VoidCallback onAddLine;

  /// Called after a frame once the last line has text; must add a line only
  /// when the last line is still non-empty.
  final VoidCallback onLastLineFilled;
  final void Function(int lineIndex) onRemoveLine;
  final void Function(int fromRow, int toRow) onReorder;
  final VoidCallback onAddHeading;
  final void Function(String headingId) onRemoveHeading;
  final void Function(int fromRow, String? headingId) onMoveLineToSection;

  final bool canAddHeading;
  final int maxLength;

  const SectionedIngredientListBuilder({
    super.key,
    required this.label,
    required this.rows,
    required this.lineControllers,
    required this.headingControllerFor,
    required this.onLineChanged,
    required this.onAddLine,
    required this.onLastLineFilled,
    required this.onRemoveLine,
    required this.onReorder,
    required this.onAddHeading,
    required this.onRemoveHeading,
    required this.onMoveLineToSection,
    required this.canAddHeading,
    this.maxLength = 500,
  });

  /// (id, label) of every heading currently in the list — feeds the
  /// "Flytta till rubrik" menu.
  List<({String id, String label})> get _headings => [
    for (final r in rows)
      if (r is HeadingRow)
        (id: r.id, label: headingControllerFor(r.id).text.trim()),
  ];

  @override
  Widget build(BuildContext context) {
    // Computed once per build (not per line row) and threaded down.
    final headings = _headings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.space8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: rows.length,
          onReorder: onReorder,
          proxyDecorator: _proxyDecorator,
          itemBuilder: (context, index) => _buildRow(context, index, headings),
        ),
        const SizedBox(height: AppDimensions.space4),
        Wrap(
          children: [
            ButleryTextButton(
              icon: ButleryIcons.plus,
              label: context.l10n.commonAddWithLabel(label.toLowerCase()),
              onPressed: onAddLine,
            ),
            ButleryTextButton(
              icon: ButleryIcons.plus,
              label: context.l10n.recipeAddIngredientHeading,
              onPressed: canAddHeading ? onAddHeading : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    List<({String id, String label})> headings,
  ) {
    // Determine this row's line index (for line rows) by counting line rows
    // before it — the same order lineControllers are supplied in.
    var lineIndex = 0;
    for (var i = 0; i < index; i++) {
      if (rows[i] is LineRow) lineIndex++;
    }
    final row = rows[index];
    if (row is HeadingRow) {
      return _buildHeadingRow(context, index, row.id);
    }
    return _buildLineRow(context, index, lineIndex, headings);
  }

  Widget _buildHeadingRow(BuildContext context, int rowIndex, String id) {
    final cs = Theme.of(context).colorScheme;
    final controller = headingControllerFor(id);
    return Padding(
      key: ValueKey('hdr_$id'),
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      // header:true flags the row as a heading. It carries NO label — a label
      // here would absorb the delete button's own Semantics.
      child: Semantics(
        header: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            border: BorderDirectional(
              start: BorderSide(color: cs.onSurface, width: 4),
            ),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: rowIndex,
                child: const Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: AppDimensions.space4,
                    end: AppDimensions.space4,
                  ),
                  child: ButleryIcon(
                    ButleryIcons.drag,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
              ),
              Expanded(
                child: ButleryRowField(
                  controller: controller,
                  hintText: context.l10n.recipeIngredientHeadingHint,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: IngredientSectionState.maxHeadingLength,
                ),
              ),
              // ≥48dp tap target; the Semantics label (not a tooltip) gives
              // the button its accessible NAME — Flutter's Tooltip contributes
              // a tooltip property, not a label, so this is what a screen
              // reader speaks and what find.bySemanticsLabel matches.
              Semantics(
                label: context.l10n.a11yRemoveIngredientHeading,
                container: true,
                button: true,
                excludeSemantics: true,
                onTap: () => onRemoveHeading(id),
                child: AppIconButton(
                  icon: ButleryIcons.trash2,
                  semanticLabel: context.l10n.a11yRemoveIngredientHeading,
                  onPressed: () => onRemoveHeading(id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineRow(
    BuildContext context,
    int rowIndex,
    int lineIndex,
    List<({String id, String label})> headings,
  ) {
    // Defensive: never index past the supplied controllers.
    if (lineIndex >= lineControllers.length) {
      return SizedBox.shrink(key: ValueKey('ing_line_missing_$rowIndex'));
    }
    return ButleryFieldRow(
      key: ValueKey('ing_line_$lineIndex'),
      children: [
        ReorderableDragStartListener(
          index: rowIndex,
          child: const Padding(
            padding: EdgeInsetsDirectional.only(end: AppDimensions.space4),
            child: ButleryIcon(
              ButleryIcons.drag,
              size: AppDimensions.iconSizeM,
            ),
          ),
        ),
        Expanded(
          child: ButleryRowField(
            controller: lineControllers[lineIndex],
            hintText: '$label ${lineIndex + 1}',
            maxLength: maxLength,
            onChanged: (value) => _handleLineChange(lineIndex, value),
          ),
        ),
        // Non-drag reassignment — only meaningful once a heading exists.
        if (headings.isNotEmpty)
          _buildMoveToSectionMenu(context, rowIndex, headings),
        if (lineControllers.length > 1)
          Semantics(
            label: context.l10n.commonRemoveLabel(
              context.l10n.recipeIngredient,
            ),
            container: true,
            button: true,
            excludeSemantics: true,
            onTap: () => onRemoveLine(lineIndex),
            child: AppIconButton(
              icon: ButleryIcons.trash2,
              semanticLabel: context.l10n.commonRemoveLabel(
                context.l10n.recipeIngredient,
              ),
              onPressed: () => onRemoveLine(lineIndex),
            ),
          ),
      ],
    );
  }

  Widget _buildMoveToSectionMenu(
    BuildContext context,
    int rowIndex,
    List<({String id, String label})> headings,
  ) {
    // PopupMenuButton never reports a null value as a selection, so
    // "no section" travels as an empty id.
    return ButleryMenu<String>(
      icon: ButleryIcons.move,
      semanticLabel: context.l10n.recipeMoveToSection,
      onSelected: (headingId) =>
          onMoveLineToSection(rowIndex, headingId.isEmpty ? null : headingId),
      choices: [
        ButleryMenuChoice<String>(
          value: '',
          label: context.l10n.recipeMoveToSectionNone,
        ),
        for (final h in headings)
          ButleryMenuChoice<String>(
            value: h.id,
            label: h.label.isEmpty
                ? context.l10n.recipeIngredientHeadingHint
                : h.label,
          ),
      ],
    );
  }

  void _handleLineChange(int lineIndex, String value) {
    onLineChanged(lineIndex, value);
    // A paste, dictation or word suggestion lands several characters in one
    // change, so the trigger is "the last line has text", not its length.
    if (lineIndex == lineControllers.length - 1 && value.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLastLineFilled());
    }
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final elevation = AnimationUtils.shouldAnimate(context)
            ? animation.value * 4
            : 4.0;
        return Material(elevation: elevation, child: child);
      },
      child: child,
    );
  }
}
