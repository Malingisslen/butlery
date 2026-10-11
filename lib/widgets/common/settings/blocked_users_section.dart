import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// The list of blocked people with unblock actions, as rows on the Blockerade
/// personer page.
class BlockedUsersSection extends StatefulWidget {
  const BlockedUsersSection({super.key});

  @override
  State<BlockedUsersSection> createState() => _BlockedUsersSectionState();
}

class _BlockedUsersSectionState extends State<BlockedUsersSection> {
  List<String> _blockedUserIds = [];
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoading = true;

  // BUT-1039: multi-select bulk-unblock (mirrors the BUT-1038 group pattern).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    final blocked = friendsService.management.getBlockedUsers();

    // Batch-fetch display names for all blocked users
    final Map<String, UserProfile> profiles = {};
    if (blocked.isNotEmpty) {
      final userService = ServiceLocator.get<UserService>();
      final result = await userService.getUserProfiles(blocked);
      for (final profile in result.profiles) {
        profiles[profile.uid] = profile;
      }
      // `_unblockUser` already falls back to the bare userId when a name is
      // missing, so an unresolved profile degrades gracefully; logged so the
      // drop is not invisible (BUT-2027).
      if (result.unavailableIds.isNotEmpty) {
        AppLogger.warning(
          'Could not resolve ${result.unavailableIds.length}/'
          '${blocked.length} blocked user profile(s)',
        );
      }
    }

    if (mounted) {
      setState(() {
        _blockedUserIds = blocked;
        _userProfiles = profiles;
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId) async {
    final displayName = _userProfiles[userId]?.displayName ?? userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.blockedUsersUnblockTitle),
        content: Text(context.l10n.blockedUsersUnblockMessage(displayName)),
        actions: [
          DialogCancelButton(onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.blockedUsersUnblock),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.management.unblockUser(userId);
      await _loadBlockedUsers();
    }
  }

  void _startSelection() {
    setState(() => _selectionMode = true);
  }

  /// Taking the last tick off leaves selection mode (produktregler.md:878).
  void _toggleSelection(String uid) {
    setState(() {
      if (!_selectedIds.remove(uid)) _selectedIds.add(uid);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _unblockSelected() async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.blockedUsersBulkUnblockTitle),
        content: Text(context.l10n.blockedUsersBulkUnblockMessage(ids.length)),
        actions: [
          DialogCancelButton(onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(context.l10n.blockedUsersUnblock),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    final succeeded = await friendsService.management.unblockUsers(ids);
    if (!mounted) return;

    // The primitive returns a success count, not failed names, so the summary
    // is count-based: a clean count, or "N of M" when some unblocks failed.
    SnackBarUtils.showInfo(
      context,
      succeeded == ids.length
          ? context.l10n.blockedUsersBulkUnblockResult(succeeded)
          : context.l10n.blockedUsersBulkUnblockPartial(succeeded, ids.length),
    );
    _cancelSelection();
    await _loadBlockedUsers();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Center(
          child: PlateLineMessage(message: l10n.loadingBlockedUsers),
        ),
      );
    }
    if (_blockedUserIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppDimensions.space16),
        child: Text(
          l10n.blockedUsersEmpty,
          style: AppTextStyles.labelMedium,
        ),
      );
    }
    final count = _selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: Text(
            l10n.blockedUsersSharesHiddenNote,
            style: AppTextStyles.labelMedium,
          ),
        ),
        ButleryListSection(rows: _blockedUserIds.map(_buildRow).toList()),
        // Selecting several is offered only when there is more than one to
        // choose between.
        if (_selectionMode)
          ButleryListSection(
            rows: [
              // The count is announced as it changes; the unblock row only
              // exists once there is something to unblock.
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.bulkSelectedCount(count),
                  style: AppTextStyles.labelMedium,
                ),
              ),
              if (count > 0)
                ButleryListRow(
                  key: const ValueKey('blocked-users-selection-count'),
                  label: l10n.blockedUsersUnblockSelectedCount(count),
                  leading: ButleryIcons.unlock,
                  onTap: _unblockSelected,
                ),
              ButleryListRow(
                key: const ValueKey('blocked-users-selection-cancel'),
                label: l10n.commonCancel,
                onTap: _cancelSelection,
              ),
            ],
          )
        else if (_blockedUserIds.length > 1)
          ButleryListSection(
            rows: [
              ButleryListRow(
                key: const ValueKey('blocked-users-select-enter'),
                label: l10n.selectionEnterBlockedUsers,
                onTap: _startSelection,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRow(String userId) {
    final displayName = _userProfiles[userId]?.displayName ?? userId;
    if (!_selectionMode) {
      return ButleryListRow(
        key: ValueKey('blocked-user-$userId'),
        label: displayName,
        value: context.l10n.blockedUsersUnblock,
        onTap: () => _unblockUser(userId),
      );
    }
    return ButleryListRow(
      key: ValueKey('blocked-user-$userId'),
      label: displayName,
      selected: _selectedIds.contains(userId),
      leading: _selectedIds.contains(userId)
          ? ButleryIcons.checkSquare
          : ButleryIcons.square,
      onTap: () => _toggleSelection(userId),
    );
  }
}
