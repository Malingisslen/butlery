// lib/widgets/common/social_components/invitation_selectors.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Focused module for invitation target selection widgets
/// 
/// This module handles ONLY selection interfaces for invitation targets:
/// - Target selectors with search and filtering
/// - Multi-select and single-select interfaces
/// - Search fields and type filters
/// - Selection interaction logic
/// 
/// ❌ DOES NOT CONTAIN: Display widgets, states, actions, target lists
class InvitationSelectors {

  // ===== TARGET SELECTORS =====

  /// Build target selector
  /// 
  /// Interactive selector for invitation targets
  static Widget targetSelector({
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    bool allowMultiSelect = true,
    bool showSearch = true,
    bool showTypeFilters = true,
    String? searchHint,
    int? maxSelections,
    Widget? emptyWidget,
    ScrollPhysics? physics,
  }) {
    // ULTRATHINK FIX: Implement concrete widget instead of circular delegation
    // Use existing components from this class to build the complete selector
    
    if (availableTargets.isEmpty) {
      return emptyWidget ?? 
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spacingLg),
            child: Text(
              'Inga målgrupper tillgängliga',
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
        );
    }

    return Column(
      children: [
        // Search field if enabled
        if (showSearch)
          targetSearchField(
            hint: searchHint,
            onSearchChanged: (query) {
              // Filter logic would be handled by parent widget
              // For now, just show the field
            },
          ),
        
        if (showSearch)
          const SizedBox(height: AppDimensions.spacingSm),

        // Type filters if enabled  
        if (showTypeFilters) ...[
          targetTypeFilters(
            availableTypes: availableTargets.map((t) => t.type.name).toSet().toList(),
            onTypesChanged: (types) {
              // Filter logic would be handled by parent widget
            },
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],

        // Target list - use appropriate selector based on allowMultiSelect
        Expanded(
          child: allowMultiSelect 
            ? checkableTargetList(
                targets: availableTargets,
                selectedTargets: selectedTargets,
                onSelectionChanged: onSelectionChanged,
                physics: physics,
              )
            : radioTargetSelector(
                targets: availableTargets,
                selectedTarget: selectedTargets?.isNotEmpty == true ? selectedTargets!.first : null,
                onSelectionChanged: (target) {
                  onSelectionChanged?.call(target != null ? [target] : []);
                },
                physics: physics,
              ),
        ),

        // Selection summary if targets are selected
        if (selectedTargets?.isNotEmpty == true)
          targetSelectionSummary(
            selectedTargets: selectedTargets!,
            compact: true,
          ),
      ],
    );
  }

  /// Build checkable target list
  /// 
  /// List with checkboxes for target selection
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    List<InvitationTarget>? selectedTargets,
    Function(List<InvitationTarget>)? onSelectionChanged,
    bool showSelectAll = true,
    String? selectAllText = 'Välj alla',
    String? selectNoneText = 'Avmarkera alla',
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return ListView.builder(
      physics: physics,
      padding: padding,
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        final isSelected = selectedTargets?.contains(target) ?? false;
        return CheckboxListTile(
          title: Text(target.displayName),
          value: isSelected,
          onChanged: (value) {
            if (onSelectionChanged != null) {
              final newSelection = List<InvitationTarget>.from(selectedTargets ?? []);
              if (value == true) {
                newSelection.add(target);
              } else {
                newSelection.remove(target);
              }
              onSelectionChanged(newSelection);
            }
          },
        );
      },
    );
  }

  /// Build radio target selector
  /// 
  /// Radio button selector for single target selection
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    InvitationTarget? selectedTarget,
    ValueChanged<InvitationTarget?>? onSelectionChanged,
    ScrollPhysics? physics,
    EdgeInsets? padding,
  }) {
    return _RadioTargetSelector(
      targets: targets,
      selectedTarget: selectedTarget,
      onSelectionChanged: onSelectionChanged,
      physics: physics,
      padding: padding,
    );
  }

  // ===== SEARCH AND FILTERING =====

  /// Build target search field
  /// 
  /// Search input for filtering targets
  static Widget targetSearchField({
    Function(String)? onSearchChanged,
    String? hint = 'Sök målgrupper...',
    IconData prefixIcon = Icons.search,
    bool autofocus = false,
    TextEditingController? controller,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(prefixIcon),
          border: const OutlineInputBorder(),
        ),
        onChanged: onSearchChanged,
      ),
    );
  }

  /// Build target type filters
  /// 
  /// Filter chips for target types
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    List<String>? selectedTypes,
    Function(List<String>)? onTypesChanged,
    bool allowMultiSelect = true,
    EdgeInsets? padding,
    double spacing = 8.0,
  }) {
    return Container(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        children: availableTypes.map((type) {
          final isSelected = selectedTypes?.contains(type) ?? false;
          return FilterChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (selected) {
              if (onTypesChanged != null) {
                final newSelection = List<String>.from(selectedTypes ?? []);
                if (selected) {
                  newSelection.add(type);
                } else {
                  newSelection.remove(type);
                }
                onTypesChanged(newSelection);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  /// Build target filtering widget
  /// 
  /// Complete filtering interface for targets
  static Widget targetFiltering({
    required List<InvitationTarget> allTargets,
    required List<InvitationTarget> filteredTargets,
    Function(List<InvitationTarget>)? onFilterChanged,
    bool showSearch = true,
    bool showTypeFilters = true,
    bool showSorting = true,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        children: [
          if (showSearch)
            targetSearchField(
              onSearchChanged: (query) {
                if (onFilterChanged != null) {
                  final filtered = allTargets.where((target) =>
                      target.displayName.toLowerCase().contains(query.toLowerCase())
                  ).toList();
                  onFilterChanged(filtered);
                }
              },
            ),
          if (showSearch && (showTypeFilters || showSorting))
            const SizedBox(height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
          if (showTypeFilters) ...[
            targetTypeFilters(
              availableTypes: allTargets.map((t) => t.type.name).toSet().toList(),
              onTypesChanged: (selectedTypes) {
                if (onFilterChanged != null) {
                  final filtered = selectedTypes.isEmpty
                      ? allTargets
                      : allTargets.where((target) => 
                          selectedTypes.contains(target.type.name)).toList();
                  onFilterChanged(filtered);
                }
              },
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          if (showSorting)
            Row(
              children: [
                const Text('Sortera:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: AppDimensions.spacingSm),
                DropdownButton<String>(
                  value: 'name',
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Namn')),
                    DropdownMenuItem(value: 'type', child: Text('Typ')),
                    DropdownMenuItem(value: 'members', child: Text('Medlemmar')),
                  ],
                  onChanged: (sortBy) {
                    if (onFilterChanged != null && sortBy != null) {
                      final sorted = List<InvitationTarget>.from(filteredTargets);
                      switch (sortBy) {
                        case 'name':
                          sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
                          break;
                        case 'type':
                          sorted.sort((a, b) => a.type.name.compareTo(b.type.name));
                          break;
                        case 'members':
                          sorted.sort((a, b) => (b.memberCount ?? 0).compareTo(a.memberCount ?? 0));
                          break;
                      }
                      onFilterChanged(sorted);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===== SELECTION MANAGEMENT =====

  /// Build target selection summary
  /// 
  /// Shows summary of selected targets
  static Widget targetSelectionSummary({
    required List<InvitationTarget> selectedTargets,
    VoidCallback? onClearAll,
    Function(InvitationTarget)? onRemoveTarget,
    String? title = 'Valda målgrupper',
    bool showClearAll = true,
    bool compact = false,
    EdgeInsets? padding,
  }) {
    if (selectedTargets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title ?? 'Valda målgrupper',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (showClearAll && onClearAll != null)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Rensa alla'),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          if (compact)
            Text(
              '${selectedTargets.length} målgrupper valda',
              style: const TextStyle(color: AppColors.textMedium),
            )
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: selectedTargets.map((target) {
                return Chip(
                  label: Text(target.displayName),
                  onDeleted: onRemoveTarget != null 
                      ? () => onRemoveTarget(target) 
                      : null,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Private widget for radio target selection without deprecated parameters
class _RadioTargetSelector extends StatefulWidget {
  final List<InvitationTarget> targets;
  final InvitationTarget? selectedTarget;
  final ValueChanged<InvitationTarget?>? onSelectionChanged;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const _RadioTargetSelector({
    required this.targets,
    this.selectedTarget,
    this.onSelectionChanged,
    this.physics,
    this.padding,
  });

  @override
  State<_RadioTargetSelector> createState() => _RadioTargetSelectorState();
}

class _RadioTargetSelectorState extends State<_RadioTargetSelector> {
  InvitationTarget? _selectedTarget;

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.selectedTarget;
  }

  @override
  void didUpdateWidget(_RadioTargetSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTarget != oldWidget.selectedTarget) {
      _selectedTarget = widget.selectedTarget;
    }
  }

  void _handleSelection(InvitationTarget? target) {
    if (mounted) {
      setState(() {
        _selectedTarget = target;
      });
      widget.onSelectionChanged?.call(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: widget.physics,
      padding: widget.padding,
      itemCount: widget.targets.length,
      itemBuilder: (context, index) {
        final target = widget.targets[index];
        final isSelected = _selectedTarget == target;
        
        return ListTile(
          leading: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Theme.of(context).primaryColor : AppColors.textMedium,
                width: 2,
              ),
              color: isSelected ? Theme.of(context).primaryColor : AppColors.transparent,
            ),
            child: isSelected 
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                )
              : null,
          ),
          title: Text(target.displayName),
          onTap: () => _handleSelection(target),
        );
      },
    );
  }
}