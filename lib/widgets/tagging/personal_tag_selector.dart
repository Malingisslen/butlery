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
import 'package:butlery/widgets/tagging/personal_tag_manager_dialog.dart';

/// Widget for selecting personal tags to apply to a recipe.
///
/// Displays available tags as chips and allows selection/deselection.
/// Includes a button to manage tags (create, edit, delete).
///
/// Works with tag NAMES (not IDs) to match how recipes store tags.
class PersonalTagSelector extends StatefulWidget {
  /// Currently selected tag names.
  final List<String> selectedTagNames;

  /// Called when selection changes. Returns list of selected tag names.
  final ValueChanged<List<String>> onChanged;

  final String? title;
  final bool showManageButton;

  const PersonalTagSelector({
    super.key,
    required this.selectedTagNames,
    required this.onChanged,
    this.title,
    this.showManageButton = true,
  });

  @Deprecated('Use selectedTagNames instead')
  List<String> get selectedTagIds => selectedTagNames;

  @override
  State<PersonalTagSelector> createState() => _PersonalTagSelectorState();
}

class _PersonalTagSelectorState extends State<PersonalTagSelector> {
  late PersonalTagViewModel _viewModel;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _viewModel = PersonalTagViewModel();
    _viewModel.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _toggleTag(PersonalTag tag) {
    final current = List<String>.from(widget.selectedTagNames);
    if (current.contains(tag.name)) {
      current.remove(tag.name);
    } else {
      current.add(tag.name);
    }
    widget.onChanged(current);
  }

  bool _isTagSelected(PersonalTag tag) {
    return widget.selectedTagNames.contains(tag.name);
  }

  Future<void> _openTagManager() async {
    await PersonalTagManagerDialog.show(context);
    // Refresh tags after manager closes
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
                  icon: const Icon(Icons.settings, size: 18),
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
            color: AppColors.textMedium.withValues(alpha: 0.5),
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
    return FilterChip(
      label: Text(tag.name),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.backgroundBeige,
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
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
              size: 14, color: AppColors.primaryBlue),
      showCheckmark: isSelected,
    );
  }
}

/// A compact display of personal tags (read-only, for recipe cards/detail views).
///
/// Works with tag NAMES (not IDs) to match how recipes store tags.
class PersonalTagDisplay extends StatelessWidget {
  /// Tag names to display (from recipe.personalTagIds).
  final List<String> tagNames;

  /// Available PersonalTag objects for color/icon lookup.
  final List<PersonalTag> availableTags;

  /// Maximum number of tags to display before showing "+N".
  final int? maxDisplay;

  const PersonalTagDisplay({
    super.key,
    required this.tagNames,
    required this.availableTags,
    this.maxDisplay,
  });

  @override
  Widget build(BuildContext context) {
    if (tagNames.isEmpty) return const SizedBox.shrink();

    final tags = tagNames
        .map((name) => availableTags.where((t) => t.name == name).firstOrNull)
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500,
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label, size: 12, color: AppColors.primaryBlue),
          const SizedBox(width: 2),
          Text(
            tag.name,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_outline,
              size: 12, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            name,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
  /// Tag names to display (from recipe.personalTagIds).
  final List<String> tagNames;

  /// Maximum number of tags to display before showing "+N".
  final int? maxDisplay;

  const AutoPersonalTagDisplay({
    super.key,
    required this.tagNames,
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
            // Notify all mounted instances
            if (mounted) {
              setState(() => _loaded = true);
            }
          },
          onError: (error) {
            AppLogger.debug('AutoPersonalTagDisplay: Stream error: $error');
            if (mounted) {
              setState(() => _loaded = true);
            }
          },
        );
      } catch (e) {
        AppLogger.debug('AutoPersonalTagDisplay: Failed to subscribe: $e');
        if (mounted) {
          setState(() => _loaded = true);
        }
      }
    }
  }

  void _unsubscribe() {
    _subscriberCount--;

    // Cancel shared subscription when last subscriber disposes
    if (_subscriberCount <= 0) {
      _sharedSubscription?.cancel();
      _sharedSubscription = null;
      _sharedTags = [];
      _subscriberCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tagNames.isEmpty) return const SizedBox.shrink();

    // Show simple chips while loading or if load failed
    if (!_loaded || _sharedTags.isEmpty) {
      return _buildSimpleChips();
    }

    // Use full PersonalTagDisplay with streamed tags
    return PersonalTagDisplay(
      tagNames: widget.tagNames,
      availableTags: _sharedTags,
      maxDisplay: widget.maxDisplay,
    );
  }

  Widget _buildSimpleChips() {
    final displayNames =
        widget.maxDisplay != null && widget.tagNames.length > widget.maxDisplay!
            ? widget.tagNames.take(widget.maxDisplay!).toList()
            : widget.tagNames;
    final remainingCount = widget.maxDisplay != null
        ? widget.tagNames.length - widget.maxDisplay!
        : 0;

    return Wrap(
      spacing: AppDimensions.spacingXs,
      runSpacing: AppDimensions.spacingXs,
      children: [
        ...displayNames.map((name) => _SimpleTagChip(name: name)),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
