// lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart

import 'dart:math' as math;

import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/pending_invitees_section.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Comprehensive member management dialog for collaborative shopping list administration
class ShoppingMemberManagementDialog extends StatefulWidget {
  final UnifiedShoppingList list;
  final Map<String, String> userDisplayNames;
  final List<UserProfile> availableFriends;

  /// Defaults to the friends service's; injectable for tests.
  final ListInvitationOperations? invitations;

  const ShoppingMemberManagementDialog({
    super.key,
    required this.list,
    required this.userDisplayNames,
    required this.availableFriends,
    this.invitations,
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
  Set<String> _pendingInvitees = const {};
  SharedListPermission _inviteLevel = SharedListPermission.edit;

  late final ListInvitationOperations _invitations;

  late Map<String, SharedListPermission> _localPermissions;
  late Set<String> _localMemberIds;

  /// BUT-1777: the list copy the rows on screen were computed from — what the
  /// user is actually looking at, captured when the dialog opened.
  ///
  /// This, not the live stream copy, is the base a permission change is judged
  /// against, so a change the owner reasoned about while their other device
  /// moved the membership is refused instead of replayed. It is NOT
  /// [_localPermissions]: `initState` seats a missing owner there for display,
  /// and shipping that synthetic entry as an access-control claim would read as
  /// drift against a server that never had it.
  ///
  /// It advances with every membership change this dialog makes itself, so a
  /// second change in the same session is not refused as its own drift.
  late UnifiedShoppingList _declaredBase;

  @override
  void initState() {
    super.initState();

    _invitations =
        widget.invitations ??
        ServiceLocator.get<UnifiedFriendsService>().invitations.listInvitations;
    _declaredBase = widget.list;
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

  /// Folds a membership change this dialog just persisted into [_declaredBase].
  void _rebaseMembers(Map<String, SharedListPermission> members) {
    _declaredBase = _declaredBase.copyWith(memberPermissions: members);
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
            viewedBase: _declaredBase,
          );

      if (success) {
        _rebaseMembers({
          ..._declaredBase.memberPermissions,
          userId: newPermission,
        });
        if (!mounted) return;
        setState(() {
          _localPermissions[userId] = newPermission;
        });

        if (mounted) {
          // The ink snackbar (PQ-09 = A).
          SnackBarUtils.showSuccess(
            context,
            context.l10n.shoppingPermissionUpdated(
              widget.userDisplayNames[userId] ??
                  context.l10n.shoppingUnknownUser,
            ),
          );
        }
      } else {
        // Consume BEFORE the mounted check: the READ is what clears the
        // reason, so bailing out first strands it for the next unrelated
        // reader to display as their cause. Same order as
        // unified_shopping_view.dart:239/:534.
        final reason = shoppingService.consumeMutationError();
        if (!mounted) return;
        setState(() {
          // BUT-1726: the service knows WHY. "Listan har ändrats på en
          // annan enhet" and "du saknar behörighet" are different problems
          // with different fixes, and only the first one is solved by
          // reloading; the generic line is the fallback, not the answer.
          _error = reason ?? context.l10n.shoppingCouldNotUpdatePermission;
        });
      }
    } catch (e) {
      AppLogger.error('Shopping member permission update failed', e);
      if (!mounted) return;
      setState(() {
        // What failed, never the exception (content-style-guide.md:95); the
        // exception goes to the log.
        _error = context.l10n.shoppingCouldNotUpdatePermission;
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
        _rebaseMembers(
          Map<String, SharedListPermission>.from(
            _declaredBase.memberPermissions,
          )..remove(userId),
        );
        if (!mounted) return;
        setState(() {
          _localPermissions.remove(userId);
          _localMemberIds.remove(userId);
          _updateFilteredFriends();
        });

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.shoppingMemberRemoved(userName),
          );
        }
      } else {
        final reason = shoppingService.consumeMutationError();
        if (!mounted) return;
        setState(() {
          _error = reason ?? context.l10n.shoppingCouldNotRemoveMember;
        });
      }
    } catch (e) {
      AppLogger.error('Shopping member removal failed', e);
      if (mounted) {
        setState(() {
          // What failed, never the exception (content-style-guide.md:95); the
          // exception goes to the log.
          _error = context.l10n.shoppingCouldNotRemoveMember;
        });
      }
    } finally {
      // `return` inside the try still runs this. The dialog is barrier-
      // dismissible, so it can be gone before the round-trip lands.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// BUT-2089: nobody is seated by someone else, so this sends invitations and
  /// the person joins when they accept.
  Future<void> _inviteSelectedFriends() async {
    if (_selectedFriends.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selected = _selectedFriends.toList();
      final summary = await _invitations.invite(
        listId: widget.list.id,
        userIds: selected,
        permission: _inviteLevel.name,
      );
      if (!mounted) return;
      final l10n = context.l10n;
      if (summary.callFailed) {
        setState(() {
          _error = summary.outcome == ListInvitationOutcome.offline
              ? l10n.errorNetwork
              : l10n.listInviteFailed;
        });
        return;
      }
      setState(() {
        _selectedFriends.clear();
        // One line for not a friend and for a block, so a block never shows.
        if (summary.notInvited.isNotEmpty) {
          _error = l10n.listInviteNotInvited(
            summary.notInvited.map(_nameOf).join(', '),
          );
        }
      });
      if (summary.invited.isNotEmpty) {
        SnackBarUtils.showSuccess(
          context,
          summary.invited.length == 1
              ? l10n.listInviteSentOne(_nameOf(summary.invited.single))
              : l10n.listInviteSentMany(summary.invited.length),
        );
      }
    } catch (e) {
      AppLogger.error('Inviting to shopping list failed', e);
      if (mounted) {
        setState(() {
          _error = context.l10n.listInviteFailed;
        });
      }
    } finally {
      // The dialog is barrier-dismissible, so it can be gone before the
      // round-trip lands.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _nameOf(String userId) =>
      widget.userDisplayNames[userId] ??
      widget.availableFriends
          .where((f) => f.uid == userId)
          .map((f) => f.displayName)
          .firstOrNull ??
      context.l10n.shoppingUnknownUser;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allMembers = Map<String, SharedListPermission>.from(
      _localPermissions,
    );

    return AlertDialog(
      title: Row(
        children: [
          ButleryIcon(
            ButleryIcons.users,
            size: AppDimensions.iconSizeM,
            color: cs.onSurface,
          ),
          const SizedBox(width: AppDimensions.space8),
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
        height: math.min(500, MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          children: [
            if (_error != null) ...[
              InlineError(what: _error!),
              const SizedBox(height: AppDimensions.space8),
            ],
            Text(
              context.l10n.shoppingCurrentMembers(allMembers.length),
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space8),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
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
            const SizedBox(height: AppDimensions.space12),
            const Divider(),
            PendingInviteesSection(
              operations: _invitations,
              listId: widget.list.id,
              nameFor: _nameOf,
              onPendingChanged: (ids) => setState(() {
                _pendingInvitees = ids;
                _selectedFriends.removeAll(ids);
              }),
            ),
            Text(
              context.l10n.listInviteHeading,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.space8),
            InviteLevelPicker(
              value: _inviteLevel,
              onChanged: _isLoading
                  ? null
                  : (level) => setState(() => _inviteLevel = level),
            ),
            const SizedBox(height: AppDimensions.space8),
            ButlerySearchBox(
              controller: _searchController,
              hintText: context.l10n.shoppingSearchFriends,
              onChanged: (_) => _updateFilteredFriends(),
            ),
            const SizedBox(height: AppDimensions.space8),
            Expanded(
              flex: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
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
              const SizedBox(height: AppDimensions.space8),
              SizedBox(
                width: double.infinity,
                child: ActionButtons.primaryButton(
                  context,
                  label: context.l10n.listInviteButtonCount(
                    _selectedFriends.length,
                  ),
                  icon: ButleryIcons.userPlus,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _inviteSelectedFriends,
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
    final tileTheme = ListTileTheme.of(context);
    // The role picker's own row starts under the name: the tile's start
    // padding, the avatar and the gap after it (Material 3 defaults when the
    // theme sets none).
    final nameInset =
        (tileTheme.contentPadding?.resolve(Directionality.of(context)).left ??
            AppDimensions.space16) +
        AvatarCircleSize.row.pixels +
        (tileTheme.horizontalTitleGap ?? AppDimensions.space16);

    final tile = ListTile(
      leading: AvatarCircle(
        displayName: userName,
        tone: AvatarCircleTone.paper,
      ),
      title: Text(
        userName,
        style: AppTextStyles.contentTitle,
      ),
      subtitle: isOwner
          ? Text(
              context.l10n.shoppingPermissionOwner,
              style: AppTextStyles.linkSmall.copyWith(
                color: context.modeColors.textLink,
              ),
            )
          : null,
      trailing: !isOwner
          ? IconButton(
              onPressed: _isLoading
                  ? null
                  : () => _removeMember(userId, userName),
              icon: ButleryIcon(ButleryIcons.userMinus, color: cs.error),
              tooltip: context.l10n.shoppingRemoveMember,
            )
          : null,
    );
    if (isOwner) return tile;

    // BUT-2190: beside the avatar and the remove button the picker had
    // too little width for "Redigera", so it takes its own row. The row
    // shares the tile's surface, so one member reads as one entry.
    return Material(
      color: tileTheme.tileColor ?? Colors.transparent,
      shape: tileTheme.shape,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile,
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: nameInset,
              end: AppDimensions.space16,
            ),
            child: PressFill(
              surface: PressSurface.base,
              child: DropdownButton<SharedListPermission>(
                icon: const ButleryIcon(ButleryIcons.chevronDown),
                iconEnabledColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                iconDisabledColor: AppModeColors.textDisabled(
                  Theme.of(context).brightness,
                ),
                isExpanded: true,
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
                        ButleryIcon(
                          ButleryIcons.eye,
                          size: AppDimensions.iconSizeS,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        Text(context.l10n.shoppingPermissionView),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: SharedListPermission.edit,
                    child: Row(
                      children: [
                        ButleryIcon(
                          ButleryIcons.pencil,
                          size: AppDimensions.iconSizeS,
                          // Saffron falls under 3:1 on the light surfaces, so
                          // only dark mode keeps it.
                          color: cs.brightness == Brightness.dark
                              ? cs.secondary
                              : cs.onSurface,
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        Text(context.l10n.shoppingPermissionEdit),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: SharedListPermission.admin,
                    child: Row(
                      children: [
                        ButleryIcon(
                          ButleryIcons.crown,
                          size: AppDimensions.iconSizeS,
                          color: cs.onSurface,
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        Text(context.l10n.shoppingPermissionAdmin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendListTile(UserProfile friend) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedFriends.contains(friend.uid);
    final invited = _pendingInvitees.contains(friend.uid);

    return ButleryCheckboxTile(
      secondary: AvatarCircle(
        imageUrl: friend.avatarUrl,
        displayName: friend.displayName,
        tone: AvatarCircleTone.paper,
      ),
      title: Text(
        friend.displayName,
        style: AppTextStyles.contentTitle,
      ),
      subtitle: invited
          ? Text(
              context.l10n.listInviteAlreadyInvited,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
      value: isSelected,
      onChanged: invited
          ? null
          : (selected) {
              setState(() {
                if (selected) {
                  _selectedFriends.add(friend.uid);
                } else {
                  _selectedFriends.remove(friend.uid);
                }
              });
            },
    );
  }
}
