// lib/widgets/messaging/builders/message_content_builder.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/messaging/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';
import 'package:butlery/models/messaging/poll.dart';

/// Builds message content widgets based on message type.
class MessageContentBuilder {
  MessageContentBuilder._();

  /// Build content widget based on message type.
  static Widget build({
    required BuildContext context,
    required Message message,
    required bool isFromCurrentUser,
    String? currentUserId,
    void Function(String optionId)? onPollVote,
    VoidCallback? onPollClose,
  }) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextContent(context, message, isFromCurrentUser);
      case MessageType.recipeShare:
        return _buildRecipeShareContent(context, message, isFromCurrentUser);
      case MessageType.menuShare:
        return _buildMenuShareContent(context, message, isFromCurrentUser);
      case MessageType.shoppingListShare:
        return _buildShoppingListShareContent(
            context, message, isFromCurrentUser);
      case MessageType.image:
        return _buildImageContent(context, message, isFromCurrentUser);
      case MessageType.voice:
        return _buildVoiceContent(context, message, isFromCurrentUser);
      case MessageType.system:
        return _buildTextContent(context, message, isFromCurrentUser);
      case MessageType.poll:
        return _buildPollContent(
          context,
          message,
          isFromCurrentUser,
          currentUserId: currentUserId ?? '',
          onVote: onPollVote,
          onClose: onPollClose,
        );
    }
  }

  static Widget _buildTextContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              context.l10n.messagingEdited,
              style: AppTextStyles.labelSmall.copyWith(
                color: isFromCurrentUser
                    ? cs.onPrimary.withValues(alpha: AppDimensions.opacityDark)
                    : cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  static Widget _buildRecipeShareContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final recipeTitle =
        message.metadata?['recipeTitle'] ?? context.l10n.messagingUnknownRecipe;
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.restaurant_menu,
      label: context.l10n.messagingRecipeShared,
      title: recipeTitle,
      subtitle: message.content.isNotEmpty &&
              message.content != 'Delade ett recept: $recipeTitle'
          ? message.content
          : null,
    );
  }

  static Widget _buildMenuShareContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final menuTitle =
        message.metadata?['menuTitle'] ?? context.l10n.messagingUnknownMenu;
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.list_alt,
      label: context.l10n.messagingMenuShared,
      title: menuTitle,
    );
  }

  static Widget _buildShoppingListShareContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final listTitle = message.metadata?['listTitle'] ??
        context.l10n.messagingUnknownShoppingList;
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.shopping_cart,
      label: context.l10n.messagingShoppingListShared,
      title: listTitle,
    );
  }

  static Widget _buildShareCard({
    required BuildContext context,
    required bool isFromCurrentUser,
    required IconData icon,
    required String label,
    required String title,
    String? subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (isFromCurrentUser ? cs.onPrimary : cs.inversePrimary)
            .withValues(alpha: AppDimensions.opacityLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: cs.inversePrimary
                  .withValues(alpha: AppDimensions.opacityMediumLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              icon,
              color: isFromCurrentUser ? cs.onPrimary : cs.primary,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isFromCurrentUser ? cs.onPrimary : cs.primary,
                  ),
                ),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isFromCurrentUser
                          ? cs.onPrimary
                              .withValues(alpha: AppDimensions.opacityVeryDark)
                          : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildImageContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = message.metadata?['imageUrl'] as String? ?? '';

    if (imageUrl.isEmpty) {
      return Text(
        context.l10n.messagingImageLoadFailed,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: context.l10n.a11yImageMessageTap,
            button: true,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FullscreenImageViewer(
                      imageUrl: imageUrl,
                      caption:
                          message.content.isNotEmpty ? message.content : null,
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildImagePlaceholder(
                    context: context,
                    isFromCurrentUser: isFromCurrentUser,
                    isLoading: true,
                  ),
                  errorWidget: (context, url, error) => _buildImagePlaceholder(
                    context: context,
                    isFromCurrentUser: isFromCurrentUser,
                    isLoading: false,
                  ),
                ),
              ),
            ),
          ),
          if (message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.paddingS),
              child: Text(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildImagePlaceholder({
    required BuildContext context,
    required bool isFromCurrentUser,
    required bool isLoading,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 150,
      color: isFromCurrentUser
          ? cs.onPrimary.withValues(alpha: AppDimensions.opacityLight)
          : cs.inversePrimary.withValues(alpha: AppDimensions.opacityLight),
      child: Center(
        child: isLoading
            ? CircularProgressIndicator(
                color: isFromCurrentUser ? cs.onPrimary : cs.primary,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: isFromCurrentUser
                        ? cs.onPrimary
                            .withValues(alpha: AppDimensions.opacityDark)
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    context.l10n.messagingImageLoadError,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isFromCurrentUser
                          ? cs.onPrimary
                              .withValues(alpha: AppDimensions.opacityDark)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static Widget _buildVoiceContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: isFromCurrentUser ? cs.onPrimary : cs.primary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            context.l10n.messagingVoiceMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPollContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser, {
    required String currentUserId,
    void Function(String optionId)? onVote,
    VoidCallback? onClose,
  }) {
    final cs = Theme.of(context).colorScheme;
    final pollData = message.metadata?['poll'] as Map<String, dynamic>?;
    if (pollData == null) {
      return Text(
        'Omröstning',
        style: AppTextStyles.bodyMedium.copyWith(
          color: isFromCurrentUser ? cs.onPrimary : cs.onSurface,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final poll = Poll.fromMap(pollData);
    return PollMessageWidget(
      poll: poll,
      currentUserId: currentUserId,
      isFromCurrentUser: isFromCurrentUser,
      onVote: onVote,
      onClose: onClose,
    );
  }
}
