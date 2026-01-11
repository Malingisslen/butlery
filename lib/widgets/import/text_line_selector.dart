/// Text line selector widget for user-assisted import.
///
/// Displays extracted text as selectable lines, allowing users to
/// tap lines to select them as ingredients or instructions.
library;

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  mode == SelectionMode.ingredients
                      ? Icons.restaurant
                      : Icons.format_list_numbered,
                  size: AppDimensions.iconSizeM,
                  color: _getModeColor(colorScheme),
                ),
                const SizedBox(width: 8),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_fields,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: AppDimensions.opacityHalf),
            ),
            const SizedBox(height: 16),
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
      backgroundColor = modeColor.withValues(alpha: AppDimensions.opacityLightSubtle);
      borderColor = modeColor;
      borderStyle = BorderStyle.solid;
    } else if (isHighlighted) {
      backgroundColor = modeColor.withValues(alpha: AppDimensions.opacityExtraVeryLight);
      borderColor = modeColor.withValues(alpha: AppDimensions.opacityHalf);
      borderStyle = BorderStyle.solid;
    } else {
      backgroundColor = AppColors.transparent;
      borderColor = colorScheme.outlineVariant;
      borderStyle = BorderStyle.none;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
                          : colorScheme.outline.withValues(alpha: AppDimensions.opacityHalf),
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
                const SizedBox(width: 12),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: AppDimensions.opacityVeryLight),
                      borderRadius: BorderRadius.circular(4),
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
