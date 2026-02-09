// lib/widgets/messaging/builders/message_content_builder.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/messaging/fullscreen_image_viewer.dart';

/// Builds message content widgets based on message type.
class MessageContentBuilder {
  MessageContentBuilder._();

  /// Build content widget based on message type.
  static Widget build({
    required BuildContext context,
    required Message message,
    required bool isFromCurrentUser,
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
    }
  }

  static Widget _buildTextContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isFromCurrentUser ? AppColors.cardWhite : AppColors.textDark,
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              'redigerad',
              style: AppTextStyles.labelSmall.copyWith(
                color: isFromCurrentUser
                    ? AppColors.cardWhite
                        .withValues(alpha: AppDimensions.opacityDark)
                    : AppColors.textMedium,
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
    final recipeTitle = message.metadata?['recipeTitle'] ?? 'Okänt recept';
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.restaurant_menu,
      label: 'Recept delat',
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
    final menuTitle = message.metadata?['menuTitle'] ?? 'Okänd meny';
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.list_alt,
      label: 'Meny delad',
      title: menuTitle,
    );
  }

  static Widget _buildShoppingListShareContent(
    BuildContext context,
    Message message,
    bool isFromCurrentUser,
  ) {
    final listTitle = message.metadata?['listTitle'] ?? 'Okänd inköpslista';
    return _buildShareCard(
      context: context,
      isFromCurrentUser: isFromCurrentUser,
      icon: Icons.shopping_cart,
      label: 'Inköpslista delad',
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
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (isFromCurrentUser ? AppColors.cardWhite : AppColors.accent)
            .withValues(alpha: AppDimensions.opacityLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.accent
                  .withValues(alpha: AppDimensions.opacityMediumLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              icon,
              color: isFromCurrentUser
                  ? AppColors.cardWhite
                  : AppColors.forestGreen,
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
                    color: isFromCurrentUser
                        ? AppColors.cardWhite
                        : AppColors.forestGreen,
                  ),
                ),
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isFromCurrentUser
                        ? AppColors.cardWhite
                        : AppColors.textDark,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isFromCurrentUser
                          ? AppColors.cardWhite
                              .withValues(alpha: AppDimensions.opacityVeryDark)
                          : AppColors.textMedium,
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
    final imageUrl = message.metadata?['imageUrl'] as String? ?? '';

    if (imageUrl.isEmpty) {
      return Text(
        'Bild kunde inte laddas',
        style: AppTextStyles.bodyMedium.copyWith(
          color: isFromCurrentUser ? AppColors.cardWhite : AppColors.textDark,
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
            label: 'Bildmeddelande, tryck för fullstorlek',
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
                    isFromCurrentUser: isFromCurrentUser,
                    isLoading: true,
                  ),
                  errorWidget: (context, url, error) => _buildImagePlaceholder(
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
                  color: isFromCurrentUser
                      ? AppColors.cardWhite
                      : AppColors.textDark,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildImagePlaceholder({
    required bool isFromCurrentUser,
    required bool isLoading,
  }) {
    return Container(
      height: 150,
      color: isFromCurrentUser
          ? AppColors.cardWhite.withValues(alpha: AppDimensions.opacityLight)
          : AppColors.accent.withValues(alpha: AppDimensions.opacityLight),
      child: Center(
        child: isLoading
            ? CircularProgressIndicator(
                color: isFromCurrentUser
                    ? AppColors.cardWhite
                    : AppColors.forestGreen,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: isFromCurrentUser
                        ? AppColors.cardWhite
                            .withValues(alpha: AppDimensions.opacityDark)
                        : AppColors.textMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    'Kunde inte ladda bild',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isFromCurrentUser
                          ? AppColors.cardWhite
                              .withValues(alpha: AppDimensions.opacityDark)
                          : AppColors.textMedium,
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
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color:
                isFromCurrentUser ? AppColors.cardWhite : AppColors.forestGreen,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Röstmeddelande',
            style: AppTextStyles.bodyMedium.copyWith(
              color:
                  isFromCurrentUser ? AppColors.cardWhite : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
