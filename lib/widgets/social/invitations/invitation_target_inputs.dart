// lib/widgets/social/invitations/invitation_target_inputs.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import 'invitation_target_displays.dart';

/// Invitation target input widgets
///
/// This module provides widgets for input and selection of invitation targets
/// including selectors, search fields, and input forms.
class InvitationTargetInputs {
  /// Build invitation target selector
  static Widget invitationTargetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    return buildTargetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
      padding: padding,
      showSelectAll: showSelectAll,
      showSearchBar: showSearchBar,
      searchHint: searchHint,
    );
  }

  /// Build invitation target chip
  static Widget invitationTargetChip({
    required InvitationTarget target,
    required bool isSelected,
    required VoidCallback onTap,
    bool showTypeIcon = true,
    bool enabled = true,
  }) {
    return InvitationTargetDisplays.buildTargetChip(
      target,
      onTap: enabled ? onTap : null,
      showCount: true,
    );
  }

  /// Build target selector with search and filtering
  static Widget buildTargetSelector({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    final selectedTargets = availableTargets
        .where((target) => selectedTargetIds.contains(target.targetId))
        .toList();

    return Padding(
      padding: padding ?? EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (title != null) ...[
            Text(
              title,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],

          // Selected targets chips
          if (selectedTargets.isNotEmpty) ...[
            _buildSelectedTargetsSection(
              selectedTargets,
              onTargetToggled,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
          ],

          // Search bar
          if (showSearchBar) ...[
            _buildTargetSearchField(
              hint: searchHint ?? 'Sök vänner och grupper...',
              onChanged: (query) {
                // Search logic would be handled by parent
                // This widget just provides the UI
              },
            ),
            const SizedBox(height: AppDimensions.spacingXl),
          ],

          // Select all button
          if (showSelectAll && availableTargets.isNotEmpty) ...[
            _buildSelectAllButton(
              availableTargets,
              selectedTargetIds,
              onTargetToggled,
              allowMultipleSelection,
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],

          // Available targets list
          _buildAvailableTargetsList(
            availableTargets: availableTargets,
            selectedTargetIds: selectedTargetIds,
            onTargetTap: onTargetToggled,
            allowMultipleSelection: allowMultipleSelection,
            emptyMessage: emptyMessage,
          ),
        ],
      ),
    );
  }

  /// Build checkable target list
  static Widget buildCheckableTargetList({
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget, bool) onTargetToggled,
    bool groupByType = true,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetsMessage();
    }

    final sortedTargets =
        groupByType ? InvitationTarget.sortForUI(targets) : targets;

    String? currentType;
    final widgets = <Widget>[];

    for (final target in sortedTargets) {
      // Add section header if grouping by type
      if (groupByType && target.type.name != currentType) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: AppDimensions.spacingXl));
        }

        widgets.add(_buildTargetSectionHeader(
          target.isGroup ? 'Grupper' : 'Vänner',
        ));

        currentType = target.type.name;
      }

      final isSelected = selectedTargetIds.contains(target.targetId);

      widgets.add(
        CheckboxListTile(
          value: isSelected,
          onChanged: (checked) => onTargetToggled(target, checked ?? false),
          contentPadding: AppDimensions.listItemPadding,
          secondary: InvitationTargetDisplays.buildTargetChip(target),
          title: Text(
            target.displayName,
            style: AppTextStyles.titleMedium,
          ),
          subtitle: target.subtitle.isNotEmpty
              ? Text(
                  target.subtitle,
                  style: AppTextStyles.titleMedium,
                )
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Build target search field
  static Widget buildTargetSearchField({
    String hint = 'Sök...',
    Function(String)? onChanged,
    VoidCallback? onClear,
  }) {
    return _buildTargetSearchField(
      hint: hint,
      onChanged: onChanged,
      onClear: onClear,
    );
  }

  /// Show target selection dialog
  static Future<List<InvitationTarget>?> showTargetSelectionDialog(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget> initialSelection = const [],
    String title = 'Välj vem du vill dela med',
    bool allowMultiple = true,
  }) {
    return showDialog<List<InvitationTarget>>(
      context: context,
      builder: (context) => _TargetSelectionDialog(
        availableTargets: availableTargets,
        initialSelection: initialSelection,
        title: title,
        allowMultiple: allowMultiple,
      ),
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Build selected targets section
  static Widget _buildSelectedTargetsSection(
    List<InvitationTarget> selectedTargets,
    Function(InvitationTarget) onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Valda (${selectedTargets.length})',
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingXs,
          children: selectedTargets.map((target) {
            return InvitationTargetDisplays.buildTargetChip(
              target,
              onRemove: () => onRemove(target),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build search field
  static Widget _buildTargetSearchField({
    required String hint,
    Function(String)? onChanged,
    VoidCallback? onClear,
  }) {
    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textLight,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: AppColors.textSecondary,
          size: AppDimensions.iconSizeAction,
        ),
        suffixIcon: onClear != null
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: AppColors.textSecondary,
                  size: AppDimensions.iconSizeAction,
                ),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppColors.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: BorderSide(color: AppColors.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: BorderSide(color: AppColors.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
    );
  }

  /// Build select all button
  static Widget _buildSelectAllButton(
    List<InvitationTarget> availableTargets,
    Set<String> selectedTargetIds,
    Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection,
  ) {
    final allSelected = availableTargets.every(
      (target) => selectedTargetIds.contains(target.targetId),
    );

    return TextButton.icon(
      onPressed: allowMultipleSelection
          ? () {
              if (allSelected) {
                // Deselect all
                for (final target in availableTargets) {
                  if (selectedTargetIds.contains(target.targetId)) {
                    onTargetToggled(target);
                  }
                }
              } else {
                // Select all
                for (final target in availableTargets) {
                  if (!selectedTargetIds.contains(target.targetId)) {
                    onTargetToggled(target);
                  }
                }
              }
            }
          : null,
      icon: Icon(
        allSelected ? Icons.deselect : Icons.select_all,
        size: AppDimensions.iconSizeAction,
      ),
      label: Text(
        allSelected ? 'Avmarkera alla' : 'Markera alla',
        style: AppTextStyles.labelLarge,
      ),
    );
  }

  /// Build available targets list
  static Widget _buildAvailableTargetsList({
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetTap,
    required bool allowMultipleSelection,
    String? emptyMessage,
  }) {
    if (availableTargets.isEmpty) {
      return _buildEmptyTargetsMessage(emptyMessage);
    }

    return Column(
      children: availableTargets.map((target) {
        final isSelected = selectedTargetIds.contains(target.targetId);
        
        return InvitationTargetDisplays.buildTargetCard(
          target,
          isSelected: isSelected,
          onTap: () => onTargetTap(target),
        );
      }).toList(),
    );
  }

  /// Build section header
  static Widget _buildTargetSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      child: Text(
        title,
        style: AppTextStyles.titleLarge,
      ),
    );
  }

  /// Build empty targets message
  static Widget _buildEmptyTargetsMessage([String? customMessage]) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: AppDimensions.iconSizeEmptyState,
            color: AppColors.textMedium,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Inga mål tillgängliga',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            customMessage ?? 'Lägg till vänner eller skapa grupper först',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===== DIALOG IMPLEMENTATION =====

/// Private dialog for target selection
class _TargetSelectionDialog extends StatefulWidget {
  final List<InvitationTarget> availableTargets;
  final List<InvitationTarget> initialSelection;
  final String title;
  final bool allowMultiple;

  const _TargetSelectionDialog({
    required this.availableTargets,
    required this.initialSelection,
    required this.title,
    required this.allowMultiple,
  });

  @override
  State<_TargetSelectionDialog> createState() => _TargetSelectionDialogState();
}

class _TargetSelectionDialogState extends State<_TargetSelectionDialog> {
  late List<InvitationTarget> selectedTargets;
  List<InvitationTarget> filteredTargets = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedTargets = List.from(widget.initialSelection);
    filteredTargets = widget.availableTargets;
  }

  void _filterTargets(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredTargets = widget.availableTargets;
      } else {
        filteredTargets = InvitationTarget.filterBySearch(
          widget.availableTargets,
          query,
        );
      }
    });
  }

  void _toggleTarget(InvitationTarget target) {
    setState(() {
      if (selectedTargets.contains(target)) {
        selectedTargets.remove(target);
      } else {
        if (!widget.allowMultiple) {
          selectedTargets.clear();
        }
        selectedTargets.add(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      title: Text(
        widget.title,
        style: AppTextStyles.titleLarge,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Search field
            InvitationTargetInputs._buildTargetSearchField(
              hint: 'Sök...',
              onChanged: _filterTargets,
              onClear: searchQuery.isNotEmpty ? () => _filterTargets('') : null,
            ),
            const SizedBox(height: AppDimensions.spacingXl),

            // Selected count
            if (selectedTargets.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingS),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: AppDimensions.iconSizeM,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Text(
                      '${selectedTargets.length} valda',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],

            // Target list
            Expanded(
              child: InvitationTargetDisplays.buildTargetList(
                filteredTargets,
                onTargetTap: _toggleTarget,
                groupByType: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          child: Text(
            'Avbryt',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedTargets),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.neutralLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: Text(
            'Välj (${selectedTargets.length})',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.neutralLight,
            ),
          ),
        ),
      ],
    );
  }
}