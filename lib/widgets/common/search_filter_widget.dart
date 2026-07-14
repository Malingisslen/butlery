// lib/widgets/common/search_filter_widget.dart - FACADE PATTERN

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Focused Components
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import 'package:butlery/widgets/common/search_filter/filter_toggle_button.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';
import 'package:butlery/widgets/common/search_filter/search_stats_widget.dart';
import 'package:butlery/widgets/voice/voice_prompt_button.dart';

// Export models for backward compatibility
export 'search_filter/filter_models.dart';

/// Search and Filter Widget API
/// This class provides a unified API for search and filter functionality:
/// - Search input field with clear functionality
/// - Filter panels with animated show/hide
/// - Filter chips for time, meal type, and rating
/// - Statistics showing search and filter results
/// - Both search-only and full filter modes
/// MIGRATION GUIDE:
/// ```dart
/// // Before: No change needed
/// SearchFilterWidget.searchOnly(searchQuery: query, onSearchChanged: onChanged);
/// SearchFilterWidget.withFilters(searchQuery: query, onSearchChanged: onChanged, ...);
/// ```
class SearchFilterWidget extends StatefulWidget {
  // Search properties
  final String searchQuery;
  final Function(String) onSearchChanged;
  final String? searchHint;

  // Filter properties (OPTIONAL - null means no filters)
  final Set<String>? activeTimeFilters;
  final Set<String>? activeMealTypeFilters;
  final Set<String>? activeRatingFilters;
  final Set<String>? activeAllergenFilters;
  final Set<String>? activeDietaryFilters;
  final Function(String)? onTimeFilterToggle;
  final Function(String)? onMealTypeFilterToggle;
  final Function(String)? onRatingFilterToggle;
  final Function(String)? onAllergenFilterToggle;
  final Function(String)? onDietaryFilterToggle;

  // Personal tag filter properties (OPTIONAL)
  final List<PersonalTag>? personalTagIds;
  final Set<String>? activePersonalTagFilters;
  final Set<String>? excludedPersonalTagFilters;
  final Function(String)? onPersonalTagFilterToggle;
  final Function(String)? onExcludedPersonalTagFilterToggle;
  final VoidCallback? onManagePersonalTags;

  /// BUT-987: deep-link to allergen/dietary preferences from the filter panel.
  final VoidCallback? onManageFoodPreferences;

  // UI state (OPTIONAL - null means no filter toggle)
  final bool? showFilters;
  final VoidCallback? onToggleFilters;
  final bool? hasActiveFilters;
  final VoidCallback? onClearAllFilters;

  // Results info (OPTIONAL)
  final int? resultCount;
  final bool showStats;

  // Search history (OPTIONAL)
  final List<String>? searchHistory;
  final Function(String)? onHistoryTap;
  final Function(String)? onHistoryRemove;

  // Search-only mode settings
  final bool searchOnly;
  final bool autofocus;
  final EdgeInsetsGeometry? padding;

  /// Opt-in mic in the search field: a spoken query lands in the box exactly
  /// as if typed (same onSearchChanged path — Algolia/Firestore routing
  /// untouched). Off by default so list surfaces that share this facade
  /// don't all sprout microphones.
  final bool enableVoiceInput;

  /// Injectable per OsPermissionHelper's contract — tests stub permission
  /// statuses without touching plugin channels.
  final PermissionGateway voicePermissionGateway;

  const SearchFilterWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.searchHint,

    // Filter properties (optional)
    this.activeTimeFilters,
    this.activeMealTypeFilters,
    this.activeRatingFilters,
    this.activeAllergenFilters,
    this.activeDietaryFilters,
    this.onTimeFilterToggle,
    this.onMealTypeFilterToggle,
    this.onRatingFilterToggle,
    this.onAllergenFilterToggle,
    this.onDietaryFilterToggle,

    // Personal tag filters (optional)
    this.personalTagIds,
    this.activePersonalTagFilters,
    this.excludedPersonalTagFilters,
    this.onPersonalTagFilterToggle,
    this.onExcludedPersonalTagFilterToggle,
    this.onManagePersonalTags,
    this.onManageFoodPreferences,

    // UI state (optional)
    this.showFilters,
    this.onToggleFilters,
    this.hasActiveFilters,
    this.onClearAllFilters,

    // Results (optional)
    this.resultCount,
    this.showStats = true,

    // Search history (optional)
    this.searchHistory,
    this.onHistoryTap,
    this.onHistoryRemove,

    // Search-only mode
    this.searchOnly = false,
    this.autofocus = false,
    this.padding,

    // Voice input (optional)
    this.enableVoiceInput = false,
    this.voicePermissionGateway = const DefaultPermissionGateway(),
  });

  /// Factory: Full search + filter functionality
  factory SearchFilterWidget.withFilters({
    required String searchQuery,
    required Function(String) onSearchChanged,
    String? searchHint,
    required Set<String> activeTimeFilters,
    required Set<String> activeMealTypeFilters,
    required Set<String> activeRatingFilters,
    required Function(String) onTimeFilterToggle,
    required Function(String) onMealTypeFilterToggle,
    required Function(String) onRatingFilterToggle,
    required bool showFilters,
    required VoidCallback onToggleFilters,
    required bool hasActiveFilters,
    required VoidCallback onClearAllFilters,
    int? resultCount,
    bool showStats = true,
    bool enableVoiceInput = false,
    PermissionGateway voicePermissionGateway = const DefaultPermissionGateway(),
  }) {
    return SearchFilterWidget(
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      searchHint: searchHint,
      activeTimeFilters: activeTimeFilters,
      activeMealTypeFilters: activeMealTypeFilters,
      activeRatingFilters: activeRatingFilters,
      onTimeFilterToggle: onTimeFilterToggle,
      onMealTypeFilterToggle: onMealTypeFilterToggle,
      onRatingFilterToggle: onRatingFilterToggle,
      showFilters: showFilters,
      onToggleFilters: onToggleFilters,
      hasActiveFilters: hasActiveFilters,
      onClearAllFilters: onClearAllFilters,
      resultCount: resultCount,
      showStats: showStats,
      enableVoiceInput: enableVoiceInput,
      voicePermissionGateway: voicePermissionGateway,
    );
  }

  /// Factory: Search-only functionality
  factory SearchFilterWidget.searchOnly({
    required String searchQuery,
    required Function(String) onSearchChanged,
    String? searchHint,
    bool autofocus = false,
    EdgeInsetsGeometry? padding,
    bool showStats = false,
    int? resultCount,
    bool enableVoiceInput = false,
    PermissionGateway voicePermissionGateway = const DefaultPermissionGateway(),
  }) {
    return SearchFilterWidget(
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      searchHint: searchHint,
      searchOnly: true,
      autofocus: autofocus,
      padding: padding,
      showStats: showStats,
      resultCount: resultCount,
      enableVoiceInput: enableVoiceInput,
      voicePermissionGateway: voicePermissionGateway,
    );
  }

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

  /// Keeps the mic's State alive when the field's suffix RESTRUCTURES —
  /// SearchInputWidget wraps the trailing slot in a Row only while the
  /// clear button is visible, so an empty↔non-empty flip would otherwise
  /// recreate VoicePromptButton mid-recording and its dispose() would
  /// silently cancel the capture (review finding, 2026-07-14).
  final GlobalKey _voiceButtonKey = GlobalKey();

  /// Whisper renders utterances as sentences ("Köttbullar."); the search
  /// filter is an exact-substring match that normalizes case/diacritics
  /// but NOT punctuation, so the sentence dressing must come off here.
  static final _edgePunctuationRe = RegExp(r'^[\s.,!?…]+|[\s.,!?…]+$');

  /// Spoken query lands as if typed: the controller listener fires
  /// onSearchChanged, so the normal search routing takes over. Selection
  /// is restored explicitly — the bare text setter leaves an invalid
  /// (-1,-1) selection that breaks continued typing.
  void _onVoiceTranscript(String transcript) {
    final query = transcript.replaceAll(_edgePunctuationRe, '');
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  Widget? _buildVoiceButton() {
    if (!widget.enableVoiceInput) return null;
    return VoicePromptButton(
      key: _voiceButtonKey,
      onTranscript: _onVoiceTranscript,
      permissionGateway: widget.voicePermissionGateway,
      startTooltip: context.l10n.voiceSearchStart,
      rationaleTitle: context.l10n.voiceSearchMicRationaleTitle,
      rationaleBody: context.l10n.voiceMicRationaleBody,
      // The suffix can stack clear + mic + filter toggle on narrow phones —
      // compact density keeps the editable region usable.
      compact: true,
    );
  }

  /// Composes the field's single trailing slot from the optional mic and an
  /// optional extra control (the filter toggle in full mode).
  Widget? _composeTrailing(Widget? extra) {
    final voice = _buildVoiceButton();
    if (voice == null) return extra;
    if (extra == null) return voice;
    return Row(mainAxisSize: MainAxisSize.min, children: [voice, extra]);
  }

  @override
  Widget build(BuildContext context) {
    // Search-only mode: just return search bar
    if (widget.searchOnly) {
      return SearchInputWidget(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: widget.searchHint,
        autofocus: widget.autofocus,
        onClear: _onSearchCleared,
        padding: widget.padding,
        trailing: _composeTrailing(null),
      );
    }

    // Full mode: search + filters + stats
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar section
        _buildSearchSection(context),

        // Search history chips (show when search is empty and history exists)
        if (_searchController.text.isEmpty &&
            widget.searchHistory != null &&
            widget.searchHistory!.isNotEmpty)
          _buildSearchHistoryChips(context),

        // Filter section with animation (only if filters are provided)
        if (_hasFilters()) _buildFilterSection(context),

        // Statistics section
        if (widget.showStats) _buildStatsSection(context),
      ],
    );
  }

  /// Check if widget has filter functionality
  bool _hasFilters() {
    return widget.activeTimeFilters != null &&
        widget.activeMealTypeFilters != null &&
        widget.activeRatingFilters != null &&
        widget.onTimeFilterToggle != null &&
        widget.onMealTypeFilterToggle != null &&
        widget.onRatingFilterToggle != null;
  }

  /// Search bar with integrated filter toggle
  Widget _buildSearchSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      child: SearchInputWidget(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: widget.searchHint,
        onClear: _onSearchCleared,
        trailing: _composeTrailing(
          _hasFilters() && widget.onToggleFilters != null
              ? FilterToggleButton(
                  showFilters: widget.showFilters ?? false,
                  hasActiveFilters: widget.hasActiveFilters ?? false,
                  onToggle: widget.onToggleFilters!,
                )
              : null,
        ),
      ),
    );
  }

  /// Animated filter section
  Widget _buildFilterSection(BuildContext context) {
    return FiltersPanelWidget(
      showFilters: widget.showFilters ?? false,
      activeTimeFilters: widget.activeTimeFilters!,
      activeMealTypeFilters: widget.activeMealTypeFilters!,
      activeRatingFilters: widget.activeRatingFilters!,
      activeAllergenFilters: widget.activeAllergenFilters ?? const {},
      activeDietaryFilters: widget.activeDietaryFilters ?? const {},
      onTimeFilterToggle: widget.onTimeFilterToggle!,
      onMealTypeFilterToggle: widget.onMealTypeFilterToggle!,
      onRatingFilterToggle: widget.onRatingFilterToggle!,
      onAllergenFilterToggle: widget.onAllergenFilterToggle,
      onDietaryFilterToggle: widget.onDietaryFilterToggle,
      hasActiveFilters: widget.hasActiveFilters ?? false,
      onClearAllFilters: widget.onClearAllFilters,
      // Personal tag filters
      personalTagIds: widget.personalTagIds,
      activePersonalTagFilters: widget.activePersonalTagFilters,
      excludedPersonalTagFilters: widget.excludedPersonalTagFilters,
      onPersonalTagFilterToggle: widget.onPersonalTagFilterToggle,
      onExcludedPersonalTagFilterToggle:
          widget.onExcludedPersonalTagFilterToggle,
      onManagePersonalTags: widget.onManagePersonalTags,
      onManageFoodPreferences: widget.onManageFoodPreferences,
    );
  }

  /// Statistics section showing results and active filters
  Widget _buildStatsSection(BuildContext context) {
    return SearchStatsWidget(
      searchQuery: widget.searchQuery,
      hasActiveFilters: widget.hasActiveFilters ?? false,
      resultCount: widget.resultCount,
      activeFilterCount: _getActiveFilterCount(),
    );
  }

  /// Recent search history chips
  Widget _buildSearchHistoryChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.searchRecentSearches,
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Wrap(
            spacing: AppDimensions.spacingXs,
            runSpacing: AppDimensions.spacingXs,
            children: widget.searchHistory!.map((query) {
              return InputChip(
                label: Text(query, style: AppTextStyles.bodySmall),
                onPressed: () {
                  _searchController.text = query;
                  widget.onHistoryTap?.call(query);
                },
                onDeleted: widget.onHistoryRemove != null
                    ? () => widget.onHistoryRemove!(query)
                    : null,
                deleteIconColor: cs.onSurfaceVariant,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimensions.spacingS),
        ],
      ),
    );
  }

  /// Get total count of active filters
  int _getActiveFilterCount() {
    return (widget.activeTimeFilters?.length ?? 0) +
        (widget.activeMealTypeFilters?.length ?? 0) +
        (widget.activeRatingFilters?.length ?? 0) +
        (widget.activeAllergenFilters?.length ?? 0) +
        (widget.activeDietaryFilters?.length ?? 0) +
        (widget.activePersonalTagFilters?.length ?? 0) +
        (widget.excludedPersonalTagFilters?.length ?? 0);
  }
}
