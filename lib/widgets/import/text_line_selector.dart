/// Text line selector widget for user-assisted import.
///
/// Displays extracted text as selectable lines, allowing users to
/// tap lines to select them as ingredients or instructions.
library;

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Selection mode for the text line selector.
enum SelectionMode {
  /// Selecting ingredient lines (green highlights)
  ingredients,

  /// Selecting instruction lines (blue highlights)
  instructions,
}

/// A widget that displays text lines for selection.
///
/// Used in user-assisted import to let users select which lines
/// are ingredients and which are instructions.
class TextLineSelector extends StatelessWidget {
  /// The lines of text to display.
  final List<String> lines;

  /// Currently selected line indices.
  final Set<int> selectedIndices;

  /// Pre-detected lines to highlight (e.g., likely ingredients).
  final Set<int> highlightedIndices;

  /// Indices to exclude from display (already used in another selection).
  final Set<int> excludedIndices;

  /// Callback when selection changes.
  final ValueChanged<Set<int>> onSelectionChanged;

  /// Current selection mode (affects colors).
  final SelectionMode mode;

  /// Optional header text.
  final String? headerText;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  const TextLineSelector({
    super.key,
    required this.lines,
    required this.selectedIndices,
    required this.onSelectionChanged,
    this.highlightedIndices = const {},
    this.excludedIndices = const {},
    this.mode = SelectionMode.ingredients,
    this.headerText,
    this.showLineNumbers = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter out excluded lines but keep original indices
    final visibleLines = <MapEntry<int, String>>[];
    for (int i = 0; i < lines.length; i++) {
      if (!excludedIndices.contains(i) && lines[i].trim().isNotEmpty) {
        visibleLines.add(MapEntry(i, lines[i]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headerText != null) ...[
          Padding(
            padding: AppDimensions.paddingSymmetric16x8,
            child: Row(
              children: [
                Icon(
                  mode == SelectionMode.ingredients
                      ? Icons.restaurant
                      : Icons.format_list_numbered,
                  size: AppDimensions.iconSizeM,
                  color: _getModeColor(colorScheme),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  headerText!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${selectedIndices.length} valda',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: visibleLines.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  itemCount: visibleLines.length,
                  padding: AppDimensions.paddingVertical8,
                  itemBuilder: (context, index) {
                    final entry = visibleLines[index];
                    return _LineItem(
                      lineIndex: entry.key,
                      text: entry.value,
                      isSelected: selectedIndices.contains(entry.key),
                      isHighlighted: highlightedIndices.contains(entry.key),
                      mode: mode,
                      showLineNumber: showLineNumbers,
                      onTap: () => _toggleLine(entry.key),
                    );
                  },
                ),
        ),
        if (highlightedIndices.isNotEmpty && selectedIndices.isEmpty)
          _buildSelectAllHighlightedButton(context),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: AppDimensions.paddingAll32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_fields,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: AppDimensions.opacityHalf),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Inga rader att visa',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllHighlightedButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: OutlinedButton.icon(
        onPressed: () {
          // Select all highlighted lines
          final newSelection = Set<int>.from(selectedIndices);
          newSelection.addAll(highlightedIndices);
          onSelectionChanged(newSelection);
        },
        icon: const Icon(Icons.select_all),
        label: Text('Välj alla markerade (${highlightedIndices.length})'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _getModeColor(colorScheme),
          side: BorderSide(color: _getModeColor(colorScheme)),
        ),
      ),
    );
  }

  void _toggleLine(int index) {
    final newSelection = Set<int>.from(selectedIndices);
    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
    }
    onSelectionChanged(newSelection);
  }

  Color _getModeColor(ColorScheme colorScheme) {
    return mode == SelectionMode.ingredients
        ? AppColors.success
        : colorScheme.primary;
  }
}

/// Individual line item in the selector.
class _LineItem extends StatelessWidget {
  final int lineIndex;
  final String text;
  final bool isSelected;
  final bool isHighlighted;
  final SelectionMode mode;
  final bool showLineNumber;
  final VoidCallback onTap;

  const _LineItem({
    required this.lineIndex,
    required this.text,
    required this.isSelected,
    required this.isHighlighted,
    required this.mode,
    required this.showLineNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine colors based on state
    final modeColor = mode == SelectionMode.ingredients
        ? AppColors.success
        : colorScheme.primary;

    Color backgroundColor;
    Color borderColor;
    BorderStyle borderStyle;

    if (isSelected) {
      backgroundColor =
          modeColor.withValues(alpha: AppDimensions.opacityLightSubtle);
      borderColor = modeColor;
      borderStyle = BorderStyle.solid;
    } else if (isHighlighted) {
      backgroundColor =
          modeColor.withValues(alpha: AppDimensions.opacityExtraVeryLight);
      borderColor = modeColor.withValues(alpha: AppDimensions.opacityHalf);
      borderStyle = BorderStyle.solid;
    } else {
      backgroundColor = AppColors.transparent;
      borderColor = colorScheme.outlineVariant;
      borderStyle = BorderStyle.none;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.spacingXxs,
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingMs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1,
                style: borderStyle,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? modeColor : AppColors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? modeColor
                          : colorScheme.outline
                              .withValues(alpha: AppDimensions.opacityHalf),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: AppDimensions.iconSizeS,
                          color: colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: AppDimensions.width12),
                // Line number (optional)
                if (showLineNumber) ...[
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${lineIndex + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
                // Line text
                Expanded(
                  child: Text(
                    text.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w500 : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Highlighted indicator
                if (isHighlighted && !isSelected) ...[
                  const SizedBox(width: AppDimensions.spacingSm),
                  Container(
                    padding: AppDimensions.paddingSymmetric6x2,
                    decoration: BoxDecoration(
                      color: modeColor.withValues(
                          alpha: AppDimensions.opacityVeryLight),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Text(
                      mode == SelectionMode.ingredients ? 'Trolig' : 'Steg',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: modeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
