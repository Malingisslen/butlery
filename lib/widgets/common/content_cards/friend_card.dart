// lib/widgets/common/content_cards/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/social_components.dart';

/// Focused module for friend card components
/// This module handles ONLY friend and user card display responsibilities:
/// - Friend card rendering with user profile data
/// - Friend request card with action buttons
/// - User avatar display and online status
/// - Friend-specific metadata (mutual friends, join date, etc.)
/// - Friend card styling and theming
/// ❌ DOES NOT CONTAIN: Recipe cards, menu cards, shopping list cards, generic content logic
class FriendCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showAvatar;
  final bool showOnlineStatus;
  final bool showMetadata;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final FriendCardStyle style;
  final String? subtitle;
  final Widget? trailing;

  const FriendCard({
    super.key,
    required this.user,
    this.onTap,
    this.onLongPress,
    this.showAvatar = true,
    this.showOnlineStatus = false,
    this.showMetadata = true,
    this.margin,
    this.padding,
    this.style = FriendCardStyle.detailed,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: margin ?? _getDefaultMargin(),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            label: context.l10n.a11yFriend(user.displayName),
            button: true,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              child: Container(
                padding: padding ?? _getDefaultPadding(),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(
                      color: AppColors.textLight,
                      width: AppDimensions.borderWidthThin),
                ),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (style) {
      case FriendCardStyle.detailed:
        return _buildDetailedContent(context);
      case FriendCardStyle.compact:
        return _buildCompactContent(context);
      case FriendCardStyle.list:
        return _buildListContent(context);
    }
  }

  Widget _buildDetailedContent(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (showAvatar) ...[
              _buildUserAvatar(context, size: 50),
              const SizedBox(width: AppDimensions.spacingM),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserName(context),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    _buildSubtitle(context),
                  ],
                  if (showMetadata) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    _buildUserMetadata(context),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        if (showAvatar) ...[
          _buildUserAvatar(context, size: 40),
          const SizedBox(width: AppDimensions.spacingM),
        ],
        Expanded(
          child: _buildUserName(context),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }

  Widget _buildListContent(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: showAvatar ? _buildUserAvatar(context, size: 40) : null,
      title: _buildUserName(context),
      subtitle: subtitle != null
          ? _buildSubtitle(context)
          : (showMetadata ? _buildUserMetadata(context) : null),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildUserAvatar(BuildContext context, {required double size}) {
    // Map size to ImageSize enum - 50+ is large, 40+ is medium, default small
    final imageSize = size >= 50
        ? ImageSize.large
        : (size >= 40 ? ImageSize.medium : ImageSize.small);

    return SocialAvatarComponents.avatar(
      user: user,
      size: imageSize,
      showOnlineStatus: showOnlineStatus,
      isOnline: user.isOnline == true,
    );
  }

  Widget _buildUserName(BuildContext context) {
    return Text(
      user.displayName,
      style: style == FriendCardStyle.compact
          ? AppTextStyles.bodyLarge
          : AppTextStyles.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Text(
      subtitle!,
      style: AppTextStyles.metadataEmphasized,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUserMetadata(BuildContext context) {
    // Build metadata based on available user information
    final metadata = <String>[];

    if (user.email.isNotEmpty) {
      metadata.add(user.email);
    }

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      metadata.join(' • '),
      style: AppTextStyles.metadataEmphasized,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case FriendCardStyle.compact:
        return const EdgeInsets.only(bottom: AppDimensions.spacingXs);
      case FriendCardStyle.list:
        return EdgeInsets.zero;
      case FriendCardStyle.detailed:
        return EdgeInsets.zero;
    }
  }

  EdgeInsets _getDefaultPadding() {
    switch (style) {
      case FriendCardStyle.compact:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingS,
        );
      case FriendCardStyle.list:
        return EdgeInsets.zero;
      case FriendCardStyle.detailed:
        return const EdgeInsets.all(AppDimensions.spacingS);
    }
  }
}

/// Friend request card with action buttons
class FriendRequestCard extends StatelessWidget {
  final FriendRequest friendRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const FriendRequestCard({
    super.key,
    required this.friendRequest,
    this.onAccept,
    this.onDecline,
    this.onTap,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          label: context.l10n.a11yFriendRequest,
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Container(
              padding: padding ?? const EdgeInsets.all(AppDimensions.spacingS),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(
                    color: AppColors.textLight,
                    width: AppDimensions.borderWidthThin),
              ),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _buildSenderAvatar(context),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.friendRequestTitle,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    context.l10n.friendWantsToBeFriend,
                    style: AppTextStyles.metadataEmphasized,
                  ),
                  if (friendRequest.message?.isNotEmpty == true) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      friendRequest.message!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (onAccept != null || onDecline != null) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildActionButtons(context),
        ],
      ],
    );
  }

  Widget _buildSenderAvatar(BuildContext context) {
    return SocialAvatarComponents.avatar(
      imageUrl: null, // FriendRequest doesn't store sender avatar directly
      displayName: '', // No sender display name available
      size: ImageSize.large, // 50px corresponds to large size
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (onDecline != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onDecline,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.textMedium),
              ),
              child: Text(
                context.l10n.friendDecline,
                style: AppTextStyles.labelMediumMuted,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),
        ],
        if (onAccept != null)
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                context.l10n.friendAccept,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Friend card display styles
enum FriendCardStyle {
  detailed, // Full visning med avatar och metadata
  compact, // Kompakt visning för listor
  list, // ListTile-baserad visning
}
