import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
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
                  child: SizedBox(
                    height: AppDimensions.spinnerSizeSmall,
                    width: AppDimensions.spinnerSizeSmall,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
            else
              ..._blockedUserIds.map(_buildBlockedUserTile),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedUserTile(String userId) {
    final profile = _userProfiles[userId];
    final displayName = profile?.displayName ?? userId;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        children: [
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
          TextButton(
            onPressed: () => _unblockUser(userId),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: AppDimensions.paddingSymmetric16x8,
            ),
            child: Text(context.l10n.blockedUsersUnblock),
          ),
        ],
      ),
    );
  }
}
