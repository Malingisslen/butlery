// lib/widgets/social/invitations/invitation_target_inputs.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../../theme/app_theme.dart';
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
      padding: padding ?? EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (title != null) ...[
            Text(
              title,
              style: AppTheme.sectionTitleStyle,
            ),
            AppTheme.smallGap,
          ],

          // Selected targets chips
          if (selectedTargets.isNotEmpty) ...[
            _buildSelectedTargetsSection(
              selectedTargets,
              onTargetToggled,
            ),
            AppTheme.mediumGap,
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
            AppTheme.mediumGap,
          ],

          // Select all button
          if (showSelectAll && availableTargets.isNotEmpty) ...[
            _buildSelectAllButton(
              availableTargets,
              selectedTargetIds,
              onTargetToggled,
              allowMultipleSelection,
            ),
            AppTheme.smallGap,
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
          widgets.add(AppTheme.mediumGap);
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
          contentPadding: AppTheme.listItemPadding,
          secondary: InvitationTargetDisplays.buildTargetChip(target),
          title: Text(
            target.displayName,
            style: AppTheme.cardTitleStyle,
          ),
          subtitle: target.subtitle.isNotEmpty
              ? Text(
                  target.subtitle,
                  style: AppTheme.subtitleStyle,
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
          style: AppTheme.sectionTitleStyle,
        ),
        AppTheme.smallGap,
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingXs,
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
      style: AppTheme.bodyStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.inputHintStyle,
        prefixIcon: Icon(
          Icons.search,
          color: AppTheme.textSecondary,
          size: AppTheme.iconSizeAction,
        ),
        suffixIcon: onClear != null
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: AppTheme.textSecondary,
                  size: AppTheme.iconSizeAction,
                ),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(color: AppTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(color: AppTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
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
        size: AppTheme.iconSizeAction,
      ),
      label: Text(
        allSelected ? 'Avmarkera alla' : 'Markera alla',
        style: AppTheme.buttonTextStyle,
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
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Text(
        title,
        style: AppTheme.sectionTitleStyle,
      ),
    );
  }

  /// Build empty targets message
  static Widget _buildEmptyTargetsMessage([String? customMessage]) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga mål tillgängliga',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          Text(
            customMessage ?? 'Lägg till vänner eller skapa grupper först',
            style: AppTheme.subtitleStyle,
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
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.largeRadius,
      ),
      title: Text(
        widget.title,
        style: AppTheme.sectionTitleStyle,
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
            AppTheme.mediumGap,

            // Selected count
            if (selectedTargets.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: AppTheme.iconSizeInfo,
                      color: AppTheme.primaryColor,
                    ),
                    AppTheme.smallHorizontalGap,
                    Text(
                      '${selectedTargets.length} valda',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AppTheme.smallGap,
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
            foregroundColor: AppTheme.textSecondary,
          ),
          child: Text(
            'Avbryt',
            style: AppTheme.buttonTextStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedTargets),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.neutralLight,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
          ),
          child: Text(
            'Välj (${selectedTargets.length})',
            style: AppTheme.buttonTextStyle.copyWith(
              color: AppTheme.neutralLight,
            ),
          ),
        ),
      ],
    );
  }
}