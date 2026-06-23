// lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Comprehensive member management dialog for collaborative shopping list administration
class ShoppingMemberManagementDialog extends StatefulWidget {
  final UnifiedShoppingList list;
  final Map<String, String> userDisplayNames;
  final List<UserProfile> availableFriends;

  const ShoppingMemberManagementDialog({
    super.key,
    required this.list,
    required this.userDisplayNames,
    required this.availableFriends,
  });

  @override
  State<ShoppingMemberManagementDialog> createState() =>
      _ShoppingMemberManagementDialogState();
}

class _ShoppingMemberManagementDialogState
    extends State<ShoppingMemberManagementDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<UserProfile> _filteredFriends = [];
  final Set<String> _selectedFriends = {};

  late Map<String, SharedListPermission> _localPermissions;
  late Set<String> _localMemberIds;

  @override
  void initState() {
    super.initState();

    _localPermissions = Map<String, SharedListPermission>.from(
      widget.list.memberPermissions,
    );

    if (!_localPermissions.containsKey(widget.list.ownerId)) {
      _localPermissions[widget.list.ownerId] = SharedListPermission.admin;
    }

    _localMemberIds = Set<String>.from(_localPermissions.keys);
    _updateFilteredFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredFriends() {
    final query = _searchController.text.toLowerCase();

    _filteredFriends = widget.availableFriends
        .where((friend) => !_localMemberIds.contains(friend.uid))
        .where((friend) => friend.displayName.toLowerCase().contains(query))
        .toList();

    setState(() {});
  }

  Future<void> _updateMemberPermission(
    String userId,
    SharedListPermission newPermission,
  ) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final success = await shoppingService.collaborative
          .updateMemberPermission(
            listId: widget.list.id,
            userId: userId,
            permission: newPermission,
          );

      if (success) {
        if (!mounted) return;
        setState(() {
          _localPermissions[userId] = newPermission;
        });

        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.shoppingPermissionUpdated(
                  widget.userDisplayNames[userId] ??
                      context.l10n.shoppingUnknownUser,
                ),
              ),
              backgroundColor: cs.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = context.l10n.shoppingCouldNotUpdatePermission;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.shoppingErrorUpdating(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingRemoveMember),
        content: Text(context.l10n.shoppingRemoveMemberConfirm(userName)),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonRemove,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final success = await shoppingService.collaborative.removeMember(
        listId: widget.list.id,
        userId: userId,
      );

      if (success) {
        setState(() {
          _localPermissions.remove(userId);
          _localMemberIds.remove(userId);
          _updateFilteredFriends();
        });

        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.shoppingMemberRemoved(userName)),
              backgroundColor: cs.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _error = context.l10n.shoppingCouldNotRemoveMember;
        });
      }
    } catch (e) {
      setState(() {
        _error = context.l10n.shoppingErrorRemoving(e.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedFriends.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final addedMembers = <String>[];

      for (final friendId in _selectedFriends) {
        final friend = widget.availableFriends.firstWhere(
          (f) => f.uid == friendId,
        );
        final success = await shoppingService.collaborative.addMember(
          listId: widget.list.id,
          userId: friendId,
          userDisplayName: friend.displayName,
          permission: SharedListPermission.edit,
        );

        if (success) {
          addedMembers.add(friendId);
        }
      }

      if (addedMembers.isNotEmpty && mounted) {
        setState(() {
          for (final friendId in addedMembers) {
            _localPermissions[friendId] = SharedListPermission.edit;
            _localMemberIds.add(friendId);
          }
          _selectedFriends.clear();
          _updateFilteredFriends();
        });
      }

      if (mounted) {
        if (addedMembers.isNotEmpty) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.shoppingMembersAdded(addedMembers.length),
              ),
              backgroundColor: cs.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _error = context.l10n.shoppingCouldNotAddMembers;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = context.l10n.shoppingErrorAdding(e.toString());
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allMembers = Map<String, SharedListPermission>.from(
      _localPermissions,
    );

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.manage_accounts, size: AppDimensions.iconSizeAction),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              context.l10n.shoppingManageSharing,
              style: AppTextStyles.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: cs.error.withValues(
                    alpha: AppDimensions.opacityVeryLight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                ),
                child: Text(
                  _error!,
                  style: AppTextStyles.bodyMediumError,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],
            Text(
              context.l10n.shoppingCurrentMembers(allMembers.length),
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                ),
                child: ListView.builder(
                  itemCount: allMembers.length,
                  itemBuilder: (context, index) {
                    final entry = allMembers.entries.elementAt(index);
                    final userId = entry.key;
                    final permission = entry.value;
                    final isOwner = userId == widget.list.ownerId;
                    final userName =
                        widget.userDisplayNames[userId] ??
                        context.l10n.shoppingUnknownUser;

                    return _buildMemberListTile(
                      userId,
                      userName,
                      permission,
                      isOwner,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            const Divider(),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              context.l10n.shoppingAddFriends,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: _searchController,
              hint: context.l10n.shoppingSearchFriends,
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => _updateFilteredFriends(),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Expanded(
              flex: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusM,
                  ),
                ),
                child: _filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? context.l10n.shoppingNoFriendsFound
                              : context.l10n.shoppingAllFriendsAreMembers,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          return _buildFriendListTile(friend);
                        },
                      ),
              ),
            ),
            if (_selectedFriends.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingM),
              SizedBox(
                width: double.infinity,
                child: ActionButtons.primaryButton(
                  context,
                  label: context.l10n.shoppingAddFriendsCount(
                    _selectedFriends.length,
                  ),
                  icon: Icons.person_add,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _addSelectedMembers,
                  isExpanded: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.commonClose,
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        ),
      ],
    );
  }

  Widget _buildMemberListTile(
    String userId,
    String userName,
    SharedListPermission permission,
    bool isOwner,
  ) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: cs.primary.withValues(
          alpha: AppDimensions.opacityVeryLight,
        ),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: AppTextStyles.labelLarge.copyWith(
            color: cs.primary,
          ),
        ),
      ),
      title: Text(
        userName,
        style: AppTextStyles.contentTitle,
      ),
      subtitle: isOwner
          ? Text(
              context.l10n.shoppingPermissionOwner,
              style: AppTextStyles.linkSmall,
            )
          : DropdownButton<SharedListPermission>(
              value: permission,
              onChanged: _isLoading
                  ? null
                  : (newPermission) {
                      if (newPermission != null) {
                        _updateMemberPermission(userId, newPermission);
                      }
                    },
              items: [
                DropdownMenuItem(
                  value: SharedListPermission.view,
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: AppDimensions.iconSizeS,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(context.l10n.shoppingPermissionView),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SharedListPermission.edit,
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: AppDimensions.iconSizeS,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(context.l10n.shoppingPermissionEdit),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SharedListPermission.admin,
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: AppDimensions.iconSizeS,
                        color: cs.primary,
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(context.l10n.shoppingPermissionAdmin),
                    ],
                  ),
                ),
              ],
            ),
      trailing: !isOwner
          ? IconButton(
              onPressed: _isLoading
                  ? null
                  : () => _removeMember(userId, userName),
              icon: Icon(Icons.person_remove, color: cs.error),
              tooltip: context.l10n.shoppingRemoveMember,
            )
          : null,
    );
  }

  Widget _buildFriendListTile(UserProfile friend) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedFriends.contains(friend.uid);

    return CheckboxListTile(
      secondary: CircleAvatar(
        radius: 20,
        backgroundColor: cs.primary.withValues(
          alpha: AppDimensions.opacityVeryLight,
        ),
        child: Text(
          friend.displayName.isNotEmpty
              ? friend.displayName[0].toUpperCase()
              : '?',
          style: AppTextStyles.labelLarge.copyWith(
            color: cs.primary,
          ),
        ),
      ),
      title: Text(
        friend.displayName,
        style: AppTextStyles.contentTitle,
      ),
      subtitle: Text(
        context.l10n.shoppingAddedWithEditPermission,
        style: AppTextStyles.bodySmall.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      value: isSelected,
      onChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedFriends.add(friend.uid);
          } else {
            _selectedFriends.remove(friend.uid);
          }
        });
      },
    );
  }
}
