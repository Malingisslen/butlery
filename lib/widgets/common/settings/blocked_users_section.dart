import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/social_components.dart';

/// Collapsible section showing blocked users with unblock actions.
/// Used in consent/privacy settings to let users manage their block list.
class BlockedUsersSection extends StatefulWidget {
  const BlockedUsersSection({super.key});

  @override
  State<BlockedUsersSection> createState() => _BlockedUsersSectionState();
}

class _BlockedUsersSectionState extends State<BlockedUsersSection> {
  List<String> _blockedUserIds = [];
  Map<String, UserProfile> _userProfiles = {};
  bool _isLoading = true;
  bool _isExpanded = false;

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
      final fetchedProfiles = await userService.getUserProfiles(blocked);
      for (final profile in fetchedProfiles) {
        profiles[profile.uid] = profile;
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
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

  void _enterSelection(String uid) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(uid);
    });
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (!_selectedIds.remove(uid)) _selectedIds.add(uid);
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded == ids.length
              ? context.l10n.blockedUsersBulkUnblockResult(succeeded)
              : context.l10n.blockedUsersBulkUnblockPartial(
                  succeeded,
                  ids.length,
                ),
        ),
      ),
    );
    _cancelSelection();
    await _loadBlockedUsers();
  }

  /// Inline action bar shown while selecting — kept self-contained inside the
  /// section's Column (no parent app-bar coordination), mirroring BUT-1038.
  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = _selectedIds.length;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingS,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.spacingXs,
        AppDimensions.spacingXxs,
        AppDimensions.spacingS,
        AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonCancel,
            visualDensity: VisualDensity.compact,
            onPressed: _cancelSelection,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: count > 0 ? _unblockSelected : null,
            icon: const Icon(Icons.lock_open),
            label: Text(context.l10n.blockedUsersUnblockSelectedCount(count)),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      child: Column(
        children: [
          // Collapsible header
          Semantics(
            label: context.l10n.a11yBlockedUsersToggle,
            button: true,
            expanded: _isExpanded,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: cs.onSurfaceVariant,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.blockedUsersTitle,
                            style: AppTextStyles.titleBold,
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            '${_blockedUserIds.length} blockerade',
                            style: AppTextStyles.metadataEmphasized,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable content
          if (_isExpanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppDimensions.spacingMd),
                child: Center(
                  child: LoadingIndicator(
                    size: AppDimensions.spinnerSizeSmall,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_blockedUserIds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Text(
                  context.l10n.blockedUsersEmpty,
                  style: AppTextStyles.metadataEmphasized,
                ),
              )
            else ...[
              if (_selectionMode) _buildSelectionBar(context),
              ..._blockedUserIds.map(_buildBlockedUserTile),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedUserTile(String userId) {
    final profile = _userProfiles[userId];
    final displayName = profile?.displayName ?? userId;
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedIds.contains(userId);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
          if (_selectionMode) ...[
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingSm),
          ],
          SocialAvatarComponents.avatar(
            user: profile,
            displayName: profile == null ? userId : null,
            size: ImageSize.medium,
          ),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(
            child: Text(
              displayName,
              style: AppTextStyles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Per-tile unblock hides in selection mode to reduce noise.
          if (!_selectionMode)
            TextButton(
              onPressed: () => _unblockUser(userId),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: AppDimensions.paddingSymmetric16x8,
              ),
              child: Text(context.l10n.blockedUsersUnblock),
            ),
        ],
      ),
    );

    // Long-press anywhere on a tile enters selection; in selection mode a tap
    // toggles. Wrapped in Semantics per the tap-target a11y rule.
    return Semantics(
      label: context.l10n.a11yBlockedUserSelect(displayName),
      button: true,
      selected: _selectionMode ? isSelected : null,
      child: InkWell(
        onLongPress: () => _enterSelection(userId),
        onTap: _selectionMode ? () => _toggleSelection(userId) : null,
        child: row,
      ),
    );
  }
}
