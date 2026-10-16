// lib/widgets/common/content_cards/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';

/// Focused module for friend card components
/// This module handles ONLY friend and user card display responsibilities:
/// - Friend card rendering with user profile data
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
    this.margin,
    this.padding,
    this.style = FriendCardStyle.detailed,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: HoverableCard(
        // Hover lift only when the card is actually tappable.
        enabled: onTap != null,
        margin: margin ?? _getDefaultMargin(),
        restDecoration: StyledCard.decorationOf(context),
        hoverDecoration: StyledCard.hoverDecorationOf(context),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            label: context.l10n.a11yFriend,
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              overlayColor: StyledCard.inkOverlayOf(context),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              child: Container(
                padding: padding ?? _getDefaultPadding(),
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
              const SizedBox(width: AppDimensions.space8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserName(context),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppDimensions.space4),
                    _buildSubtitle(context),
                  ],
                ],
              ),
            ),
            ?trailing,
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
          const SizedBox(width: AppDimensions.space8),
        ],
        Expanded(
          child: _buildUserName(context),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildListContent(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: showAvatar ? _buildUserAvatar(context, size: 40) : null,
      title: _buildUserName(context),
      subtitle: subtitle != null ? _buildSubtitle(context) : null,
      trailing: trailing,
    );
  }

  Widget _buildUserAvatar(BuildContext context, {required double size}) {
    // Map size to ImageSize enum - 50+ is large, 40+ is medium, default small
    final imageSize = size >= 50
        ? ImageSize.large
        : (size >= 40 ? ImageSize.medium : ImageSize.small);

    return SocialAvatarComponents.avatar(
      announceName: false,
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
      style: AppTextStyles.labelMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case FriendCardStyle.compact:
        return const EdgeInsets.only(bottom: AppDimensions.space4);
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
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.space4,
        );
      case FriendCardStyle.list:
        // ListTile's own side inset, which its contentPadding gives up.
        return const EdgeInsets.symmetric(horizontal: AppDimensions.space16);
      case FriendCardStyle.detailed:
        return const EdgeInsets.all(AppDimensions.space4);
    }
  }
}

/// Friend card display styles
enum FriendCardStyle {
  detailed, // Full visning med avatar och metadata
  compact, // Compact display for lists
  list, // ListTile-baserad visning
}
