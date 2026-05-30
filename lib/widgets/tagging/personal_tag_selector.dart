import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/widgets/common/state/skeleton_components.dart';

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
          _error = context.l10n.personalTagCouldNotLoad;
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
    final cs = Theme.of(context).colorScheme;
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
                  label: Text(context.l10n.personalTagManage),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
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
                    child: LoadingIndicator(size: 24, strokeWidth: 2),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.label_outline,
            color: cs.onSurfaceVariant
                .withValues(alpha: AppDimensions.opacityHalf),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              context.l10n.personalTagEmptyTitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _openTagManager,
            child: Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
  }

  /// HIGH-7: Error state with retry button.
  Widget _buildErrorState(String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color:
                cs.error.withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: cs.error,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.error,
              ),
            ),
          ),
          TextButton(
            onPressed: _retryLoad,
            child: Text(context.l10n.commonRetry),
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
    final cs = Theme.of(context).colorScheme;
    // MED-12: Accessibility label for screen readers
    return Semantics(
      label: isSelected
          ? context.l10n.personalTagChipSelectedA11y(tag.name)
          : context.l10n.personalTagChipUnselectedA11y(tag.name),
      selected: isSelected,
      button: true,
      child: FilterChip(
        label: Text(tag.name),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: cs.surface,
        selectedColor: cs.primary.withValues(alpha: AppDimensions.opacityLight),
        checkmarkColor: cs.primary,
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant,
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: isSelected ? cs.primary : cs.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        avatar: isSelected
            ? null
            : Icon(Icons.label_outline,
                size: AppDimensions.iconSize14, color: cs.primary),
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
    final cs = Theme.of(context).colorScheme;
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
              color: cs.surface,
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
    final cs = Theme.of(context).colorScheme;
    // MED-12: Accessibility label for screen readers
    return Semantics(
      label: context.l10n.personalTagA11yLabel(tag.name),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.spacingXs),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: AppDimensions.opacityLightSubtle),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          border: Border.all(
            color:
                cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label,
                size: AppDimensions.iconSizeXs, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingXxs),
            Text(
              tag.name,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTagChip extends StatelessWidget {
  const _PlaceholderTagChip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS,
          vertical: AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(
          color: cs.primary.withValues(alpha: AppDimensions.opacityMediumLight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline,
              size: AppDimensions.iconSizeXs, color: cs.primary),
          const SizedBox(width: AppDimensions.spacingXs),
          SkeletonComponents.skeletonBox(
            width: 48,
            height: 12,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
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
  /// BUT-1055: shared invalidation subscription for all instances. Replaces
  /// the former always-on `watchTags().snapshots()` listener — we no longer
  /// hold a live Firestore listener open for the whole time any tagged
  /// recipe card is visible. Instead one shared `tagsMutated` subscription
  /// triggers an on-demand `getAllTags()` re-fetch (served from the service's
  /// 5-min cache between mutations).
  static StreamSubscription<void>? _mutationSubscription;

  /// BUT-1170: shared subscription to [PersonalTagService.instanceReady]. Lets
  /// the static state re-bind [_mutationSubscription] to a fresh service
  /// instance after a logout→login while cards stay mounted. Torn down with the
  /// last subscriber.
  static StreamSubscription<void>? _instanceReadySubscription;
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

    // BUT-1170: re-bind to a fresh service instance after a re-login. Set up
    // once (first subscriber) and survives across logout/login because it
    // listens to a static, class-level signal — not the instance that gets
    // swapped. Torn down with the last subscriber in [_unsubscribe].
    _instanceReadySubscription ??=
        PersonalTagService.instanceReady.listen((_) => _onInstanceReady());

    // Bind the shared invalidation subscription if this is the first subscriber
    // (or if a prior logout dropped it). The mutation signal re-fetches; the
    // bind also kicks off one initial fetch so the first mount populates without
    // waiting for a write.
    _bindMutationSubscription();
  }

  /// BUT-1055/BUT-1170: binds [_mutationSubscription] to the CURRENT service
  /// instance's `tagsMutated` stream. Idempotent — no-ops if already bound.
  /// The `onDone` handler drops the subscription when its controller closes on
  /// logout, so [_onInstanceReady] can re-bind to the next login's instance.
  static void _bindMutationSubscription() {
    if (_mutationSubscription != null) return;
    try {
      final service = ServiceLocator.get<PersonalTagService>();
      _mutationSubscription = service.tagsMutated.listen(
        (_) => _refetchAndNotify(service),
        onError: (error) {
          AppLogger.debug('AutoPersonalTagDisplay: Mutation error: $error');
          _notifyAll();
        },
        onDone: () {
          // BUT-1170: the bound service was torn down (logout closed the crud
          // `tagsMutated` controller). Drop the dead subscription and clear
          // shared state; the next login re-binds via instanceReady.
          _mutationSubscription = null;
          _sharedTags = [];
          _notifyAll();
        },
      );
      _refetchAndNotify(service); // initial / re-bind load
    } catch (e) {
      // No live service yet (e.g. mid logout→login gap). Stay in the
      // placeholder state; instanceReady will re-bind once login completes.
      AppLogger.debug('AutoPersonalTagDisplay: Failed to subscribe: $e');
      _notifyAll();
    }
  }

  /// BUT-1170: a fresh user-scoped [PersonalTagService] finished initializing
  /// (login). Re-bind the shared mutation subscription to it so mounted cards
  /// resume updating without having to unmount first.
  static void _onInstanceReady() {
    _mutationSubscription?.cancel();
    _mutationSubscription = null;
    _sharedTags = [];
    if (_subscriberCount > 0) {
      _bindMutationSubscription();
    }
  }

  /// Re-reads the tag set on demand and notifies every mounted instance.
  /// Called on first mount and on each `tagsMutated` event. The cache was
  /// cleared by the mutation before the event fired, so this read is fresh.
  static Future<void> _refetchAndNotify(PersonalTagService service) async {
    try {
      _sharedTags = await service.getAllTags();
    } catch (e) {
      AppLogger.debug('AutoPersonalTagDisplay: getAllTags failed: $e');
    }
    _notifyAll();
  }

  /// MED-10: Notify ALL registered listeners, not just the first instance.
  static void _notifyAll() {
    for (final listener in _listeners.toList()) {
      listener();
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

    // Cancel shared subscriptions when last subscriber disposes
    if (_subscriberCount <= 0) {
      _mutationSubscription?.cancel();
      _mutationSubscription = null;
      // BUT-1170: also drop the instance-ready listener so we don't keep a
      // dangling subscription open after every card is gone.
      _instanceReadySubscription?.cancel();
      _instanceReadySubscription = null;
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
    final cs = Theme.of(context).colorScheme;
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
        ...displayIds.map((_) => const _PlaceholderTagChip()),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
                vertical: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: cs.surface,
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
