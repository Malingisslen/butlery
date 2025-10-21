// lib/widgets/messaging/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/models/messaging/message.dart';
// MessageStatus and MessageType available through message.dart import
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/widgets/messaging/fullscreen_image_viewer.dart';

/// Message bubble component for displaying individual messages in chat
///
/// Provides different styling for sent vs received messages with:
/// - Message content with proper formatting
/// - Message status indicators (sent, delivered, read)
/// - Timestamp display and edited indicators
/// - Recipe/menu share previews
/// - Reply preview support
/// - Swipe-to-reply gesture
/// - Proper Swedish localization
class MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final Message? replyToMessage; // The message being replied to
  final bool showAvatar;
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.onReply,
    this.replyToMessage,
    this.showAvatar = true,
    this.showTimestamp = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  double _dragExtent = 0;
  static const double _swipeThreshold = 80.0;
  static const double _maxSwipe = 120.0;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  bool get _isFromCurrentUser => widget.message.isFromCurrentUser(widget.currentUserId);
  bool get _isSystemMessage => widget.message.isSystemMessage;

  @override
  Widget build(BuildContext context) {
    if (_isSystemMessage) {
      return _buildSystemMessage(context);
    }

    return GestureDetector(
      onHorizontalDragUpdate: widget.onReply != null ? _handleDragUpdate : null,
      onHorizontalDragEnd: widget.onReply != null ? _handleDragEnd : null,
      child: AnimatedBuilder(
        animation: _swipeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: _swipeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.spacingXs,
              ),
              child: Stack(
                alignment: _isFromCurrentUser
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                children: [
                  // Reply icon that appears during swipe
                  if (_dragExtent.abs() > 10)
                    Positioned(
                      left: _isFromCurrentUser ? 20 : null,
                      right: !_isFromCurrentUser ? 20 : null,
                      child: Opacity(
                        opacity: (_dragExtent.abs() / _swipeThreshold).clamp(0.0, 1.0),
                        child: const Icon(
                          Icons.reply,
                          color: AppColors.success,
                          size: 24,
                        ),
                      ),
                    ),
                  // Message content
                  Row(
                    mainAxisAlignment: _isFromCurrentUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!_isFromCurrentUser && widget.showAvatar) ...[
                        _buildAvatar(context),
                        const SizedBox(width: AppDimensions.paddingS),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: _isFromCurrentUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!_isFromCurrentUser && !widget.showAvatar)
                              _buildSenderName(context),
                            _buildMessageCard(context),
                            if (widget.showTimestamp) _buildTimestamp(context),
                          ],
                        ),
                      ),
                      if (_isFromCurrentUser && widget.showAvatar) ...[
                        const SizedBox(width: AppDimensions.paddingS),
                        _buildAvatar(context),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;

    setState(() {
      // For received messages (left side), swipe right (positive delta)
      // For sent messages (right side), swipe left (negative delta)
      final delta = details.primaryDelta ?? 0;

      if (_isFromCurrentUser) {
        // Sent messages: swipe left
        _dragExtent = (delta < 0) ? delta.clamp(-_maxSwipe, 0) : 0;
      } else {
        // Received messages: swipe right
        _dragExtent = (delta > 0) ? delta.clamp(0, _maxSwipe) : 0;
      }
    });

    // Update animation
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(_dragExtent / 10, 0), // Reduced movement for better feel
    ).animate(_swipeController);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.onReply == null) return;

    // Trigger reply if threshold was met
    if (_dragExtent.abs() >= _swipeThreshold) {
      widget.onReply?.call();
    }

    // Reset animation
    setState(() {
      _dragExtent = 0;
    });
    _swipeAnimation = Tween<Offset>(
      begin: _swipeAnimation.value,
      end: Offset.zero,
    ).animate(_swipeController);
    _swipeController.forward(from: 0);
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: AppColors.textTertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Text(
            widget.message.content,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMedium,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: 0.2),
      ),
      child: widget.message.senderAvatarUrl != null
          ? SimpleImageWidget(
              imageUrl: widget.message.senderAvatarUrl!,
              config: ImageConfig.avatar(
                size: ImageSize.small,
              ),
              placeholder: _buildAvatarFallback(),
            )
          : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Text(
        widget.message.senderDisplayName.isNotEmpty
            ? widget.message.senderDisplayName[0].toUpperCase()
            : '?',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingS,
        bottom: AppDimensions.spacingXs,
      ),
      child: Text(
        widget.message.senderDisplayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textMedium,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: StyledCard(
        backgroundColor: _isFromCurrentUser
            ? AppColors.primaryBlue
            : AppColors.cardWhite,
        borderRadius: AppDimensions.borderRadiusM,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message.isReply && widget.replyToMessage != null)
              _buildReplyPreview(context),
            _buildMessageContent(context),
            if (_isFromCurrentUser)
              _buildMessageStatus(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final replyTo = widget.replyToMessage;
    if (replyTo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (_isFromCurrentUser ? AppColors.cardWhite : AppColors.accent)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: const Border(
          left: BorderSide(
            color: AppColors.accent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo.senderDisplayName,
            style: AppTextStyles.labelMedium.copyWith(
              color: _isFromCurrentUser
                  ? AppColors.cardWhite.withValues(alpha: 0.8)
                  : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing2),
          Text(
            replyTo.displayContent,
            style: AppTextStyles.labelSmall.copyWith(
              color: _isFromCurrentUser
                  ? AppColors.cardWhite.withValues(alpha: 0.7)
                  : AppColors.textMedium,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextContent(context);
      case MessageType.recipeShare:
        return _buildRecipeShareContent(context);
      case MessageType.menuShare:
        return _buildMenuShareContent(context);
      case MessageType.shoppingListShare:
        return _buildShoppingListShareContent(context);
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.voice:
        return _buildVoiceContent(context);
      case MessageType.system:
        return _buildTextContent(context); // System messages handled separately
    }
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.message.content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: _isFromCurrentUser
                ? AppColors.cardWhite
                : AppColors.textDark,
          ),
        ),
        if (widget.message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              'redigerad',
              style: AppTextStyles.labelSmall.copyWith(
                color: _isFromCurrentUser
                    ? AppColors.cardWhite.withValues(alpha: 0.7)
                    : AppColors.textMedium,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecipeShareContent(BuildContext context) {
    final recipeTitle = widget.message.metadata?['recipeTitle'] ?? 'Okänt recept';
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (_isFromCurrentUser ? AppColors.cardWhite : AppColors.accent)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: _isFromCurrentUser 
                  ? AppColors.cardWhite 
                  : AppColors.primaryBlue,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🍽️ Recept delat',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.primaryBlue,
                  ),
                ),
                Text(
                  recipeTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.textDark,
                  ),
                ),
                if (widget.message.content.isNotEmpty && widget.message.content != 'Delade ett recept: $recipeTitle')
                  Text(
                    widget.message.content,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _isFromCurrentUser 
                          ? AppColors.cardWhite.withValues(alpha: 0.8)
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

  Widget _buildMenuShareContent(BuildContext context) {
    final menuTitle = widget.message.metadata?['menuTitle'] ?? 'Okänd meny';
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (_isFromCurrentUser ? AppColors.cardWhite : AppColors.accent)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              Icons.list_alt,
              color: _isFromCurrentUser 
                  ? AppColors.cardWhite 
                  : AppColors.primaryBlue,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📋 Meny delad',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.primaryBlue,
                  ),
                ),
                Text(
                  menuTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingListShareContent(BuildContext context) {
    final listTitle = widget.message.metadata?['listTitle'] ?? 'Okänd inköpslista';
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (_isFromCurrentUser ? AppColors.cardWhite : AppColors.accent)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Icon(
              Icons.shopping_cart,
              color: _isFromCurrentUser 
                  ? AppColors.cardWhite 
                  : AppColors.primaryBlue,
              size: AppDimensions.iconSizeM,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🛒 Inköpslista delad',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.primaryBlue,
                  ),
                ),
                Text(
                  listTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _isFromCurrentUser 
                        ? AppColors.cardWhite 
                        : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    // For image messages, URL is stored in metadata
    final imageUrl = widget.message.metadata?['imageUrl'] as String? ?? '';

    if (imageUrl.isEmpty) {
      // Fallback if no image URL
      return Text(
        'Bild kunde inte laddas',
        style: AppTextStyles.bodyMedium.copyWith(
          color: _isFromCurrentUser
              ? AppColors.cardWhite
              : AppColors.textDark,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 250,
        maxHeight: 300,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image with tap to fullscreen
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullscreenImageViewer(
                    imageUrl: imageUrl,
                    caption: widget.message.content.isNotEmpty ? widget.message.content : null,
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: _isFromCurrentUser
                      ? AppColors.cardWhite.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.2),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _isFromCurrentUser
                          ? AppColors.cardWhite
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: _isFromCurrentUser
                      ? AppColors.cardWhite.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: _isFromCurrentUser
                            ? AppColors.cardWhite.withValues(alpha: 0.7)
                            : AppColors.textMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Kunde inte ladda bild',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _isFromCurrentUser
                              ? AppColors.cardWhite.withValues(alpha: 0.7)
                              : AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Caption if available
          if (widget.message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.paddingS),
              child: Text(
                widget.message.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _isFromCurrentUser
                      ? AppColors.cardWhite
                      : AppColors.textDark,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: _isFromCurrentUser 
                ? AppColors.cardWhite 
                : AppColors.primaryBlue,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Text(
            'Röstmeddelande',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _isFromCurrentUser 
                  ? AppColors.cardWhite 
                  : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: AppDimensions.iconSizeXs,
            color: AppColors.cardWhite.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppDimensions.spacing2),
          Text(
            _getStatusText(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.cardWhite.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppDimensions.spacingXs,
        left: _isFromCurrentUser ? 0 : AppDimensions.paddingS,
        right: _isFromCurrentUser ? AppDimensions.paddingS : 0,
      ),
      child: Text(
        _getFormattedTimestamp(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textLight,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (widget.message.status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  String _getStatusText() {
    switch (widget.message.status) {
      case MessageStatus.sending:
        return 'Skickar';
      case MessageStatus.sent:
        return 'Skickat';
      case MessageStatus.delivered:
        return 'Levererat';
      case MessageStatus.read:
        return 'Läst';
      case MessageStatus.failed:
        return 'Misslyckades';
    }
  }

  String _getFormattedTimestamp() {
    final now = DateTime.now();
    final messageTime = widget.message.sentAt;
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${messageTime.day}/${messageTime.month}';
    }
  }
}