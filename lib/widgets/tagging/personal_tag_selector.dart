import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';

/// Widget for selecting personal tags to apply to a recipe.
///
/// Displays available tags as chips and allows selection/deselection.
/// Includes a button to manage tags (create, edit, delete).
///
/// Works with tag IDs (UUIDs) to match Phase 2 storage format.
class PersonalTagSelector extends StatefulWidget {
  /// Currently selected tag IDs (UUIDs).
  final List<String> selectedTagIds;

  /// Called when selection changes. Returns list of selected tag IDs.
  final ValueChanged<List<String>> onChanged;

  final String? title;
  final bool showManageButton;

  const PersonalTagSelector({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
    this.title,
    this.showManageButton = true,
  });

  @override
  State<PersonalTagSelector> createState() => _PersonalTagSelectorState();
}

class _PersonalTagSelectorState extends State<PersonalTagSelector> {
  late PersonalTagViewModel _viewModel;
  bool _initialized = false;
  String? _error; // HIGH-7: Track error state

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<PersonalTagViewModel>();
    // Singleton is already initialized by DI
    _initialized = true;
  }

  Future<void> _retryLoad() async {
    setState(() {
      _initialized = false;
      _error = null;
    });
    // Re-initialize from the singleton
    try {
      await _viewModel.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialized = true;
          _error = 'Kunde inte ladda taggar';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleTag(PersonalTag tag) {
    final current = List<String>.from(widget.selectedTagIds);
    if (current.contains(tag.id)) {
      current.remove(tag.id);
    } else {
      current.add(tag.id);
    }
    widget.onChanged(current);
  }

  bool _isTagSelected(PersonalTag tag) {
    return widget.selectedTagIds.contains(tag.id);
  }

  Future<void> _openTagManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalTagsView()),
    );
    // Refresh tags after returning from tag management view
    await _viewModel.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (widget.title != null)
                Expanded(
                  child: Text(
                    widget.title!,
                    style: AppTextStyles.labelMedium,
                  ),
                ),
              if (widget.showManageButton)
                TextButton.icon(
                  onPressed: _openTagManager,
                  icon: const Icon(Icons.settings,
                      size: AppDimensions.iconSize18),
                  label: const Text('Hantera'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingS,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),

          // Tags
          Consumer<PersonalTagViewModel>(
            builder: (context, viewModel, _) {
              if (!_initialized || viewModel.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingM),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              // HIGH-7: Show error state if loading failed
              if (_error != null) {
                return _buildErrorState(_error!);
              }

              if (!viewModel.hasTags) {
                return _buildEmptyState();
              }

              return _buildTagChips(viewModel.tags);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.backgroundBeige,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            color: AppColors.textMedium
                .withValues(alpha: AppDimensions.opacityHalf),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              'Inga taggar skapade',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
          TextButton(
            onPressed: _openTagManager,
            child: const Text('Skapa'),
          ),
        ],
      ),
    );
  }

  /// HIGH-7: Error state with retry button.
  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color:
            AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color: AppColors.error
                .withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          TextButton(
            onPressed: _retryLoad,
            child: const Text('Försök igen'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChips(List<PersonalTag> tags) {
    return Wrap(
      spacing: AppDimensions.spacingS,
      runSpacing: AppDimensions.spacingS,
      children: tags.map((tag) {
        final isSelected = _isTagSelected(tag);
        return _PersonalTagChip(
          tag: tag,
          isSelected: isSelected,
          onTap: () => _toggleTag(tag),
        );
      }).toList(),
    );
  }
}

class _PersonalTagChip extends StatelessWidget {
  final PersonalTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalTagChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // MED-12: Accessibility label for screen readers
    return Semantics(
      label: isSelected
          ? '${tag.name}, vald. Dubbeltryck för att ta bort.'
          : '${tag.name}. Dubbeltryck för att välja.',
      selected: isSelected,
      button: true,
      child: FilterChip(
        label: Text(tag.name),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.backgroundBeige,
        selectedColor:
            AppColors.primaryBlue.withValues(alpha: AppDimensions.opacityLight),
        checkmarkColor: AppColors.primaryBlue,
        side: BorderSide(
          color: isSelected ? AppColors.primaryBlue : AppColors.divider,
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        avatar: isSelected
            ? null
            : const Icon(Icons.label_outline,
                size: AppDimensions.iconSize14, color: AppColors.primaryBlue),
        showCheckmark: isSelected,
      ),
    );
  }
}

/// A compact display of personal tags (read-only, for recipe cards/detail views).
///
/// Works with tag IDs (UUIDs) to match how recipes store tags.
class PersonalTagDisplay extends StatelessWidget {
  /// Tag IDs to display (from recipe.personalTagIds).
  final List<String> tagIds;

  /// Available PersonalTag objects for name/icon lookup.
  final List<PersonalTag> availableTags;

  /// Maximum number of tags to display before showing "+N".
  final int? maxDisplay;

  const PersonalTagDisplay({
    super.key,
    required this.tagIds,
    required this.availableTags,
    this.maxDisplay,
  });

  @override
  Widget build(BuildContext context) {
    if (tagIds.isEmpty) return const SizedBox.shrink();

    final tags = tagIds
        .map((id) => availableTags.where((t) => t.id == id).firstOrNull)
        .whereType<PersonalTag>()
        .toList();

    if (tags.isEmpty) return const SizedBox.shrink();

    final displayTags = maxDisplay != null && tags.length > maxDisplay!
        ? tags.take(maxDisplay!)
        : tags;
    final remainingCount = maxDisplay != null ? tags.length - maxDisplay! : 0;

    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: [
        ...displayTags.map((tag) => _MiniTagChip(tag: tag)),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            ),
            child: Text(
              '+$remainingCount',
              style: AppTextStyles.metadataEmphasized,
            ),
          ),
      ],
    );
  }
}

class _MiniTagChip extends StatelessWidget {
  final PersonalTag tag;

  const _MiniTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    // MED-12: Accessibility label for screen readers
    return Semantics(
      label: 'Tagg: ${tag.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.spacingXs),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue
              .withValues(alpha: AppDimensions.opacityLightSubtle),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          border: Border.all(
            color: AppColors.primaryBlue
                .withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.label,
                size: AppDimensions.iconSizeXs, color: AppColors.primaryBlue),
            const SizedBox(width: AppDimensions.spacingXxs),
            Text(
              tag.name,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple chip for displaying a tag name without PersonalTag lookup.
///
/// Used as fallback when PersonalTag data isn't available.
class _SimpleTagChip extends StatelessWidget {
  final String name;

  const _SimpleTagChip({required this.name});

  @override
  Widget build(BuildContext context) {
    // MED-12: Accessibility label for screen readers
    return Semantics(
      label: 'Tagg: $name',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.spacingXs),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue
              .withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          border: Border.all(
            color: AppColors.primaryBlue
                .withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.label_outline,
                size: AppDimensions.iconSizeXs, color: AppColors.primaryBlue),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              name,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-loading display of personal tags that fetches tag data automatically.
///
/// Use this when you don't have access to the PersonalTag list.
/// Falls back to simple text chips if tags can't be loaded.
///
/// **Performance Note**: Uses a shared cache to avoid redundant Firebase queries
/// when multiple instances are displayed (e.g., in recipe card lists).
class AutoPersonalTagDisplay extends StatefulWidget {
  /// Tag IDs to display (from recipe.personalTagIds).
  final List<String> tagIds;

  /// Maximum number of tags to display before showing "+N".
  final int? maxDisplay;

  const AutoPersonalTagDisplay({
    super.key,
    required this.tagIds,
    this.maxDisplay,
  });

  @override
  State<AutoPersonalTagDisplay> createState() => _AutoPersonalTagDisplayState();
}

class _AutoPersonalTagDisplayState extends State<AutoPersonalTagDisplay> {
  /// Shared stream subscription for all AutoPersonalTagDisplay instances.
  /// Avoids redundant Firebase queries while providing real-time updates.
  static StreamSubscription<List<PersonalTag>>? _sharedSubscription;
  static List<PersonalTag> _sharedTags = [];
  static int _subscriberCount = 0;

  /// MED-10: Static callback list for all instances.
  /// Each instance registers its own callback to properly check its mounted state.
  static final List<VoidCallback> _listeners = [];

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _subscriberCount++;

    // MED-10: Add this instance's callback to the list
    _listeners.add(_onTagsUpdated);

    // If we already have data, mark as loaded immediately
    if (_sharedTags.isNotEmpty) {
      _loaded = true;
    }

    // Start shared subscription if this is the first subscriber
    if (_sharedSubscription == null) {
      try {
        final service = ServiceLocator.get<PersonalTagService>();
        _sharedSubscription = service.watchTags().listen(
          (tags) {
            _sharedTags = tags;
            // MED-10: Notify ALL registered listeners, not just the first instance
            for (final listener in _listeners.toList()) {
              listener();
            }
          },
          onError: (error) {
            AppLogger.debug('AutoPersonalTagDisplay: Stream error: $error');
            // MED-10: Notify ALL registered listeners on error
            for (final listener in _listeners.toList()) {
              listener();
            }
          },
        );
      } catch (e) {
        AppLogger.debug('AutoPersonalTagDisplay: Failed to subscribe: $e');
        _onTagsUpdated(); // Notify just this instance on setup failure
      }
    }
  }

  /// MED-10: Instance-specific callback that checks this instance's mounted state.
  void _onTagsUpdated() {
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  void _unsubscribe() {
    // MED-10: Remove this instance's callback from the list
    _listeners.remove(_onTagsUpdated);
    _subscriberCount--;

    // Cancel shared subscription when last subscriber disposes
    if (_subscriberCount <= 0) {
      _sharedSubscription?.cancel();
      _sharedSubscription = null;
      _sharedTags = [];
      _subscriberCount = 0;
      _listeners.clear(); // MED-10: Clear listeners list
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tagIds.isEmpty) return const SizedBox.shrink();

    // Show simple chips while loading or if load failed
    if (!_loaded || _sharedTags.isEmpty) {
      return _buildSimpleChips();
    }

    // Use full PersonalTagDisplay with streamed tags
    return PersonalTagDisplay(
      tagIds: widget.tagIds,
      availableTags: _sharedTags,
      maxDisplay: widget.maxDisplay,
    );
  }

  Widget _buildSimpleChips() {
    final displayIds =
        widget.maxDisplay != null && widget.tagIds.length > widget.maxDisplay!
            ? widget.tagIds.take(widget.maxDisplay!).toList()
            : widget.tagIds;
    final remainingCount = widget.maxDisplay != null
        ? widget.tagIds.length - widget.maxDisplay!
        : 0;

    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: [
        ...displayIds.map((id) => _SimpleTagChip(name: id)),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            ),
            child: Text(
              '+$remainingCount',
              style: AppTextStyles.metadataEmphasized,
            ),
          ),
      ],
    );
  }
}
