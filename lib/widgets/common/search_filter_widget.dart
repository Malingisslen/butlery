// lib/widgets/common/search_filter_widget.dart

/// 🔍 AI INFO BLOCK:
/// Component: SearchFilterWidget - Unified search and filter functionality
/// File: widgets/common/search_filter_widget.dart
/// Quick Guide: Combines search bar + filter chips + animations in ONE component
/// Dependencies IN: AppTheme, ViewModels (for state)
/// Dependencies OUT: Used by recipe/menu list views
/// Data flow: User input → Widget state → ViewModel updates → UI refresh
/// State management: Internal state for UI, ViewModel for business logic
/// Purpose: Replaces separate search_bar.dart + filter_chips.dart
/// Common issues: Ensure proper controller disposal
/// Test coverage: 90% (critical for search/filter UX)
/// Performance: Optimized rebuilds, efficient animations
/// Analytics: Search queries, filter usage patterns
/// Code smells: ✅ Single responsibility - search + filter cohesion
/// Connected to: RecipeListViewModel, MenuViewModel
/// Used in phases: Fas 2 - Widget consolidation

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Unified search and filter widget that replaces separate components
/// REGEL: Functional cohesion - search and filter belong together
class SearchFilterWidget extends StatefulWidget {
  // Search properties
  final String searchQuery;
  final Function(String) onSearchChanged;
  final String searchHint;

  // Filter properties
  final Set<String> activeTimeFilters;
  final Set<String> activeMealTypeFilters;
  final Set<String> activeRatingFilters;
  final Function(String) onTimeFilterToggle;
  final Function(String) onMealTypeFilterToggle;
  final Function(String) onRatingFilterToggle;

  // UI state
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final bool hasActiveFilters;
  final VoidCallback onClearAllFilters;

  // Results info
  final int? resultCount;
  final bool showStats;

  const SearchFilterWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.searchHint = 'Sök...',
    required this.activeTimeFilters,
    required this.activeMealTypeFilters,
    required this.activeRatingFilters,
    required this.onTimeFilterToggle,
    required this.onMealTypeFilterToggle,
    required this.onRatingFilterToggle,
    required this.showFilters,
    required this.onToggleFilters,
    required this.hasActiveFilters,
    required this.onClearAllFilters,
    this.resultCount,
    this.showStats = true,
  });

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _searchFocusNode = FocusNode();

    // Listen to search changes
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void didUpdateWidget(SearchFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller if search query changed externally
    if (widget.searchQuery != oldWidget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    widget.onSearchChanged(_searchController.text);
  }

  void _onSearchCleared() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar section
        _buildSearchSection(context),

        // Filter section with animation
        _buildFilterSection(context),

        // Statistics section
        if (widget.showStats) _buildStatsSection(context),
      ],
    );
  }

  /// Search bar with integrated filter toggle
  Widget _buildSearchSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: AppTheme.bodyStyle,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: AppTheme.inputHintStyle,
                prefixIcon: Icon(
                  Icons.search,
                  size: AppTheme.iconSizeAction,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: AppTheme.iconSizeAction,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _onSearchCleared,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: AppTheme.mediumRadius,
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppTheme.mediumRadius,
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: AppTheme.inputPadding,
              ),
            ),
          ),

          AppTheme.smallHorizontalGap,

          // Filter toggle button
          Container(
            decoration: BoxDecoration(
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(
                color: widget.showFilters
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: widget.showFilters ? 2 : 1,
              ),
              color: widget.showFilters
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
            ),
            child: Stack(
              children: [
                IconButton(
                  onPressed: widget.onToggleFilters,
                  icon: Icon(
                    Icons.filter_list,
                    color: widget.showFilters
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: widget.showFilters ? 'Dölj filter' : 'Visa filter',
                ),
                // Active filters indicator
                if (widget.hasActiveFilters && !widget.showFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Animated filter section
  Widget _buildFilterSection(BuildContext context) {
    return AnimatedSize(
      duration: AppTheme.animationDurationMedium,
      curve: Curves.easeInOut,
      child: widget.showFilters
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time filters
                  _buildFilterGroup(
                    context,
                    title: 'Tillagningstid',
                    options: RecipeFilters.timeFilters,
                    activeFilters: widget.activeTimeFilters,
                    onToggle: widget.onTimeFilterToggle,
                  ),

                  // Meal type filters
                  _buildFilterGroup(
                    context,
                    title: 'Måltidstyp',
                    options: RecipeFilters.mealTypeFilters,
                    activeFilters: widget.activeMealTypeFilters,
                    onToggle: widget.onMealTypeFilterToggle,
                  ),

                  // Rating filters
                  _buildFilterGroup(
                    context,
                    title: 'Betyg',
                    options: RecipeFilters.ratingFilters,
                    activeFilters: widget.activeRatingFilters,
                    onToggle: widget.onRatingFilterToggle,
                  ),

                  // Clear all filters button
                  if (widget.hasActiveFilters) ...[
                    AppTheme.smallGap,
                    Center(
                      child: TextButton.icon(
                        onPressed: widget.onClearAllFilters,
                        icon: Icon(
                          Icons.clear_all,
                          size: AppTheme.iconSizeAction,
                        ),
                        label: Text(
                          'Rensa alla filter',
                          style: AppTheme.buttonTextStyle,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],

                  AppTheme.smallGap,
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Build filter group with chips
  Widget _buildFilterGroup(
    BuildContext context, {
    required String title,
    required List<FilterOption> options,
    required Set<String> activeFilters,
    required Function(String) onToggle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.smallGap,
          Text(
            title,
            style: AppTheme.sectionTitleStyle.copyWith(
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          AppTheme.tinyGap,
          Wrap(
            spacing: AppTheme.spacingXs,
            runSpacing: AppTheme.spacingXs,
            children: options.map((option) {
              final isSelected = activeFilters.contains(option.id);

              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: AppTheme.iconSizeSmall,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      AppTheme.tinyGap,
                    ],
                    Text(
                      option.label,
                      style: AppTheme.chipLabelStyle.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => onToggle(option.id),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.chipRadius,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Statistics section showing results and active filters
  Widget _buildStatsSection(BuildContext context) {
    if (!_shouldShowStats()) return const SizedBox.shrink();

    final statsText = _buildStatsText();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: AppTheme.iconSizeInfo,
            color: Theme.of(context).colorScheme.primary,
          ),
          AppTheme.tinyGap,
          Expanded(
            child: Text(
              statsText,
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if stats should be shown
  bool _shouldShowStats() {
    return widget.searchQuery.isNotEmpty ||
        widget.hasActiveFilters ||
        widget.resultCount != null;
  }

  /// Build stats text
  String _buildStatsText() {
    final parts = <String>[];

    if (widget.searchQuery.isNotEmpty) {
      parts.add('Sökning: "${widget.searchQuery}"');
    }

    if (widget.hasActiveFilters) {
      final filterCount = widget.activeTimeFilters.length +
          widget.activeMealTypeFilters.length +
          widget.activeRatingFilters.length;
      parts.add('$filterCount filter aktiva');
    }

    if (widget.resultCount != null) {
      parts.add('${widget.resultCount} resultat');
    }

    return parts.join(' • ');
  }
}

/// Filter option data model
class FilterOption {
  final String id;
  final String label;
  final IconData? icon;
  final dynamic value;

  const FilterOption({
    required this.id,
    required this.label,
    this.icon,
    this.value,
  });
}

/// Predefined recipe filters
class RecipeFilters {
  static const List<FilterOption> timeFilters = [
    FilterOption(
      id: 'quick',
      label: '< 30 min',
      icon: Icons.timer,
      value: 30,
    ),
    FilterOption(
      id: 'medium',
      label: '30-60 min',
      icon: Icons.timer,
      value: 60,
    ),
    FilterOption(
      id: 'long',
      label: '> 60 min',
      icon: Icons.timer,
      value: 999,
    ),
  ];

  static const List<FilterOption> mealTypeFilters = [
    FilterOption(
      id: 'breakfast',
      label: 'Frukost',
      icon: Icons.breakfast_dining,
      value: 'Frukost',
    ),
    FilterOption(
      id: 'lunch',
      label: 'Lunch',
      icon: Icons.lunch_dining,
      value: 'Lunch',
    ),
    FilterOption(
      id: 'dinner',
      label: 'Middag',
      icon: Icons.dinner_dining,
      value: 'Middag',
    ),
    FilterOption(
      id: 'snack',
      label: 'Mellanmål',
      icon: Icons.cookie,
      value: 'Mellanmål',
    ),
    FilterOption(
      id: 'dessert',
      label: 'Efterrätt',
      icon: Icons.cake,
      value: 'Efterrätt',
    ),
  ];

  static const List<FilterOption> ratingFilters = [
    FilterOption(
      id: 'high_rated',
      label: '4+ ⭐',
      value: 4.0,
    ),
    FilterOption(
      id: 'top_rated',
      label: '5 ⭐',
      value: 5.0,
    ),
  ];
}
