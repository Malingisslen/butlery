// lib/widgets/common/content_cards/friend_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
    final cs = Theme.of(context).colorScheme;
    final restDecoration = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      border: Border.all(
        color: cs.outline,
        width: AppDimensions.borderWidthThin,
      ),
    );
    return RepaintBoundary(
      child: HoverableCard(
        // Hover lift only when the card is actually tappable.
        enabled: onTap != null,
        margin: margin ?? _getDefaultMargin(),
        restDecoration: restDecoration,
        // Hover fills to surface.raised (B83-1 = A, BUT-2183,
        // produktbeslut-2026-09-30.json).
        hoverDecoration: restDecoration.copyWith(
          color: cs.surfaceContainerHighest,
          boxShadow: AppShadows.subtle,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            label: context.l10n.a11yFriend(user.displayName),
            button: true,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              overlayColor: HoverableCard.inkOverlay(cs),
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
          const SizedBox(width: AppDimensions.spacingM),
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
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.space4,
        );
      case FriendCardStyle.list:
        return EdgeInsets.zero;
      case FriendCardStyle.detailed:
        return const EdgeInsets.all(AppDimensions.space4);
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

  /// The request itself carries only the sender's uid, so the caller looks the
  /// name up. Without it the person accepting cannot tell who asked.
  final String? senderName;
  final String? senderAvatarUrl;

  const FriendRequestCard({
    super.key,
    required this.friendRequest,
    this.onAccept,
    this.onDecline,
    this.onTap,
    this.margin,
    this.padding,
    this.senderName,
    this.senderAvatarUrl,
  });

  String? get _name =>
      senderName?.trim().isNotEmpty == true ? senderName!.trim() : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          label: context.l10n.a11yFriendRequest,
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: PressFill(
              surface: PressSurface.base,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusControl,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                  ),
                  child: Container(
                    padding:
                        padding ?? const EdgeInsets.all(AppDimensions.space4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: AppDimensions.borderWidthThin,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusControl,
                      ),
                    ),
                    child: _buildContent(context),
                  ),
                ),
              ),
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
                    _name ?? context.l10n.friendRequestTitle,
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
      imageUrl: senderAvatarUrl,
      displayName: _name.orEmpty(),
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
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              child: Text(
                context.l10n.friendDecline,
                semanticsLabel: _name == null
                    ? null
                    : context.l10n.a11yDeclineFriendRequestFrom(_name!),
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
                semanticsLabel: _name == null
                    ? null
                    : context.l10n.a11yAcceptFriendRequestFrom(_name!),
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
  compact, // Compact display for lists
  list, // ListTile-baserad visning
}
