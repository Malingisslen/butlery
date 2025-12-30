import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/tagging/personal_tag_color_picker.dart';
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
    final tagColor = PersonalTagColors.fromHex(tag.color);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.icon != null) ...[
            Text(tag.icon!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
          ],
          Text(tag.name),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.backgroundBeige,
      selectedColor: tagColor.withValues(alpha: 0.2),
      checkmarkColor: tagColor,
      side: BorderSide(
        color: isSelected ? tagColor : AppColors.divider,
      ),
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? tagColor : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      avatar: isSelected
          ? null
          : PersonalTagColorDot(color: tag.color, size: 10),
      showCheckmark: isSelected,
    );
  }
}

/// A compact display of personal tags (read-only, for recipe cards/detail views).
///
/// Works with tag NAMES (not IDs) to match how recipes store tags.
class PersonalTagDisplay extends StatelessWidget {
  /// Tag names to display (from recipe.personalTags).
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
    final remainingCount =
        maxDisplay != null ? tags.length - maxDisplay! : 0;

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
    final tagColor = PersonalTagColors.fromHex(tag.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tagColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.icon != null) ...[
            Text(tag.icon!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 2),
          ],
          Text(
            tag.name,
            style: AppTextStyles.bodySmall.copyWith(
              color: tagColor,
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
          const Icon(Icons.label_outline, size: 12, color: AppColors.primaryBlue),
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
class AutoPersonalTagDisplay extends StatefulWidget {
  /// Tag names to display (from recipe.personalTags).
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
  List<PersonalTag>? _availableTags;
  bool _loaded = false;
  PersonalTagViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      _viewModel = PersonalTagViewModel();
      await _viewModel!.initialize();
      if (mounted) {
        setState(() {
          _availableTags = _viewModel!.tags;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tagNames.isEmpty) return const SizedBox.shrink();

    // Show simple chips while loading or if load failed
    if (!_loaded || _availableTags == null) {
      return _buildSimpleChips();
    }

    // Use full PersonalTagDisplay with loaded tags
    return PersonalTagDisplay(
      tagNames: widget.tagNames,
      availableTags: _availableTags!,
      maxDisplay: widget.maxDisplay,
    );
  }

  Widget _buildSimpleChips() {
    final displayNames = widget.maxDisplay != null &&
            widget.tagNames.length > widget.maxDisplay!
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
