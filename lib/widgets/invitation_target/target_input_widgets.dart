// lib/widgets/invitation_target/target_input_widgets.dart

import 'package:flutter/material.dart';
import '../../models/invitations/invitation_target.dart';
import '../../theme/app_theme.dart';
import 'target_display_widgets.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Target Input Widgets - UI komponenter för input/selection av InvitationTarget
/// File: widgets/invitation_target/target_input_widgets.dart
/// Quick Guide: Widget builders för att välja och hantera InvitationTarget input - använder BARA AppTheme
/// Dependencies IN: InvitationTarget, AppTheme, TargetDisplayWidgets
/// Dependencies OUT: UI screens, dialogs, forms
/// Data flow: User input → Widget callbacks → Parent state updates → Re-render
/// State management: Stateless widgets som kommunicerar via callbacks
/// Purpose: Separation of concerns - input komponenter använder centraliserad AppTheme
/// Common issues: Ensure proper callback handling and state updates
/// Test coverage: 0% (UI widgets)
/// Performance: ⚡ Efficient rendering, avoid unnecessary rebuilds
/// Analytics: N/A - UI widgets
/// Code smells: ✅ Single responsibility - bara input handling med AppTheme
/// Connected to: TargetDisplayWidgets, InvitationTarget, various input forms
/// Used in phases: Fas 1 (Grundinfrastruktur) - UI foundation

/// Widget builders för att hantera InvitationTarget input och selection
///
/// Denna klass innehåller BARA input-relaterade widgets som:
/// - Hanterar target selection
/// - Hanterar target search och filtering
/// - Hanterar target creation
/// - Kommunicerar via callbacks
/// - Använder AppTheme för ALL styling
class TargetInputWidgets {
  // ===== SELECTION WIDGETS =====

  /// Bygg target selector med search och filtering
  static Widget buildTargetSelector(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    required List<InvitationTarget> selectedTargets,
    required Function(InvitationTarget) onTargetSelected,
    required Function(InvitationTarget) onTargetDeselected,
    String searchHint = 'Sök vänner och grupper...',
    bool allowMultiple = true,
    bool showSearch = true,
    bool groupByType = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected targets chips
        if (selectedTargets.isNotEmpty) ...[
          _buildSelectedTargetsSection(
            context,
            selectedTargets,
            onTargetDeselected,
          ),
          AppTheme.mediumGap,
        ],

        // Search bar
        if (showSearch) ...[
          _buildTargetSearchField(
            context,
            hint: searchHint,
            onChanged: (query) {
              // Search logic would be handled by parent
              // This widget just provides the UI
            },
          ),
          AppTheme.mediumGap,
        ],

        // Available targets list
        _buildAvailableTargetsList(
          context,
          availableTargets: availableTargets,
          selectedTargets: selectedTargets,
          onTargetTap: (target) {
            final isSelected = selectedTargets.contains(target);
            if (isSelected) {
              onTargetDeselected(target);
            } else {
              if (!allowMultiple) {
                // Clear all selections first
                for (final selected in selectedTargets) {
                  onTargetDeselected(selected);
                }
              }
              onTargetSelected(target);
            }
          },
          groupByType: groupByType,
        ),
      ],
    );
  }

  /// Bygg checkable target lista
  static Widget buildCheckableTargetList(
    BuildContext context, {
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget, bool) onTargetToggled,
    bool groupByType = true,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetsMessage(context);
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

        widgets.add(TargetDisplayWidgets.buildTargetSectionHeader(
          context,
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
          secondary: TargetDisplayWidgets.buildTargetBadge(context, target),
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

  /// Bygg radio target selector (single selection)
  static Widget buildRadioTargetSelector(
    BuildContext context, {
    required List<InvitationTarget> targets,
    InvitationTarget? selectedTarget,
    required Function(InvitationTarget?) onTargetSelected,
    bool groupByType = true,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetsMessage(context);
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

        widgets.add(TargetDisplayWidgets.buildTargetSectionHeader(
          context,
          target.isGroup ? 'Grupper' : 'Vänner',
        ));

        currentType = target.type.name;
      }

      widgets.add(
        RadioListTile<InvitationTarget>(
          value: target,
          groupValue: selectedTarget,
          onChanged: onTargetSelected,
          contentPadding: AppTheme.listItemPadding,
          secondary: TargetDisplayWidgets.buildTargetBadge(context, target),
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

  // ===== SEARCH AND FILTER WIDGETS =====

  /// Bygg search field för targets
  static Widget buildTargetSearchField(
    BuildContext context, {
    String hint = 'Sök...',
    Function(String)? onChanged,
    VoidCallback? onClear,
  }) {
    return _buildTargetSearchField(
      context,
      hint: hint,
      onChanged: onChanged,
      onClear: onClear,
    );
  }

  /// Bygg filter chips för target types
  static Widget buildTargetTypeFilters(
    BuildContext context, {
    required Set<InvitationTargetType> selectedTypes,
    required Function(InvitationTargetType, bool) onTypeToggled,
  }) {
    return Wrap(
      spacing: AppTheme.spacingSm,
      children: InvitationTargetType.values.map((type) {
        final isSelected = selectedTypes.contains(type);
        final label =
            type == InvitationTargetType.individual ? 'Vänner' : 'Grupper';

        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) => onTypeToggled(type, selected),
          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
          checkmarkColor: AppTheme.primaryColor,
        );
      }).toList(),
    );
  }

  // ===== QUICK SELECTION WIDGETS =====

  /// Bygg quick selection buttons för vanliga val
  static Widget buildQuickSelectionButtons(
    BuildContext context, {
    required List<InvitationTarget> allTargets,
    required Function(List<InvitationTarget>) onTargetsSelected,
  }) {
    final individuals = InvitationTarget.individualsOnly(allTargets);
    final groups = InvitationTarget.groupsOnly(allTargets);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Snabbval',
          style: AppTheme.sectionTitleStyle,
        ),
        AppTheme.smallGap,
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingXs,
          children: [
            // Alla vänner
            if (individuals.isNotEmpty)
              _buildQuickSelectionChip(
                context,
                'Alla vänner (${individuals.length})',
                () => onTargetsSelected(individuals),
              ),

            // Alla grupper
            if (groups.isNotEmpty)
              _buildQuickSelectionChip(
                context,
                'Alla grupper (${groups.length})',
                () => onTargetsSelected(groups),
              ),

            // Alla
            if (allTargets.isNotEmpty)
              _buildQuickSelectionChip(
                context,
                'Alla (${allTargets.length})',
                () => onTargetsSelected(allTargets),
              ),

            // Rensa
            _buildQuickSelectionChip(
              context,
              'Rensa alla',
              () => onTargetsSelected([]),
              isDestructive: true,
            ),
          ],
        ),
      ],
    );
  }

  // ===== DIALOG BUILDERS =====

  /// Bygg target selection dialog
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

  /// Bygg selected targets section
  static Widget _buildSelectedTargetsSection(
    BuildContext context,
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
        TargetDisplayWidgets.buildTargetChipWrap(
          context,
          selectedTargets,
          onChipRemove: onRemove,
        ),
      ],
    );
  }

  /// Bygg search field
  static Widget _buildTargetSearchField(
    BuildContext context, {
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

  /// Bygg available targets list
  static Widget _buildAvailableTargetsList(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    required List<InvitationTarget> selectedTargets,
    required Function(InvitationTarget) onTargetTap,
    bool groupByType = true,
  }) {
    if (availableTargets.isEmpty) {
      return _buildEmptyTargetsMessage(context);
    }

    return TargetDisplayWidgets.buildTargetList(
      context,
      availableTargets,
      onTargetTap: onTargetTap,
      groupByType: groupByType,
    );
  }

  /// Bygg empty targets message
  static Widget _buildEmptyTargetsMessage(BuildContext context) {
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
            'Lägg till vänner eller skapa grupper först',
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Bygg quick selection chip
  static Widget _buildQuickSelectionChip(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: AppTheme.chipLabelStyle.copyWith(
          color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: onTap,
      backgroundColor: isDestructive
          ? AppTheme.errorColor.withValues(alpha: 0.1)
          : AppTheme.primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.chipRadius,
        side: BorderSide(
          color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
          width: 1,
        ),
      ),
    );
  }
}

// ===== DIALOG IMPLEMENTATION =====

/// Private dialog för target selection
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
            TargetInputWidgets._buildTargetSearchField(
              context,
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
              child: TargetDisplayWidgets.buildTargetList(
                context,
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
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
          ),
          child: Text(
            'Välj (${selectedTargets.length})',
            style: AppTheme.buttonTextStyle.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
