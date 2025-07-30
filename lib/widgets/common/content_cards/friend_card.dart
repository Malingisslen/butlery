// lib/widgets/common/content_cards/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart' as image_config;

/// Focused module for friend card components
/// 
/// This module handles ONLY friend and user card display responsibilities:
/// - Friend card rendering with user profile data
/// - Friend request card with action buttons
/// - User avatar display and online status
/// - Friend-specific metadata (mutual friends, join date, etc.)
/// - Friend card styling and theming
/// 
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
    return Container(
      margin: margin ?? _getDefaultMargin(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: padding ?? _getDefaultPadding(),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: AppColors.textLight, width: AppDimensions.borderWidthThin),
            ),
            child: _buildContent(context),
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
      subtitle: subtitle != null ? _buildSubtitle(context) : 
                (showMetadata ? _buildUserMetadata(context) : null),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildUserAvatar(BuildContext context, {required double size}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: SimpleImageWidget(
            imageUrl: user.avatarUrl,
            fit: BoxFit.cover,
            placeholder: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.backgroundTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: size * 0.6,
                color: AppColors.textMedium,
              ),
            ),
            config: const image_config.ImageConfig(
              type: image_config.ImageType.avatar,
              size: image_config.ImageSize.medium,
            ),
          ),
        ),
        if (showOnlineStatus)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: user.isOnline == true ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.backgroundLight,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
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
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
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
    
    // Note: UserProfile doesn't have createdAt field
    // This section would need to be updated when user metadata is available
    /*
    if (user.createdAt != null) {
      final joinDate = DateTime.fromMillisecondsSinceEpoch(user.createdAt!);
      final now = DateTime.now();
      final difference = now.difference(joinDate);
      
      if (difference.inDays < 30) {
        metadata.add('Medlem i ${difference.inDays} dagar');
      } else if (difference.inDays < 365) {
        metadata.add('Medlem i ${(difference.inDays / 30).round()} månader');
      } else {
        metadata.add('Medlem i ${(difference.inDays / 365).round()} år');
      }
    }
    */
    
    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Text(
      metadata.join(' • '),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(color: AppColors.textLight, width: AppDimensions.borderWidthThin),
            ),
            child: _buildContent(context),
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
                  const Text(
                    'Friend Request', // FriendRequest doesn't store sender display name directly
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    'Vill bli din vän',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMedium),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.borderRadius25),
      child: SimpleImageWidget(
        imageUrl: null, // FriendRequest doesn't store sender avatar directly
        fit: BoxFit.cover,
        placeholder: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: AppColors.backgroundTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            size: 30,
            color: AppColors.textMedium,
          ),
        ),
        config: const image_config.ImageConfig(
          type: image_config.ImageType.avatar,
          size: image_config.ImageSize.medium,
        ),
      ),
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
                'Avvisa',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMedium),
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
                'Acceptera',
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
  detailed,  // Full visning med avatar och metadata
  compact,   // Kompakt visning för listor
  list,      // ListTile-baserad visning
}