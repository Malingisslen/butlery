// lib/widgets/messaging/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';
import 'package:butlery/widgets/messaging/components/message_status_widget.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';

/// Message bubble component for chat messages.
/// Uses extracted components from [MessageContentBuilder],
/// [MessageStatusWidget], and [SystemMessageWidget].
class MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final Message? replyToMessage; // The message being replied to
  final bool showAvatar;
  final bool showTimestamp;
  final void Function(String emoji)? onReactionToggle;
  final void Function(String optionId)? onPollVote;
  final VoidCallback? onPollClose;

  /// BUT-1904: clears the duplicate-guard notice. Ignored for every other
  /// message type — only the blocked branch below reads it.
  ///
  /// Returns whether the delete succeeded. The control disables itself on tap
  /// so a double tap cannot reach a document that is already gone, and a false
  /// answer is what re-enables it — otherwise a failed delete leaves the user
  /// told it failed with no way to try again.
  final Future<bool> Function()? onDismissBlocked;

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
    this.onReactionToggle,
    this.onPollVote,
    this.onPollClose,
    this.onDismissBlocked,
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
  bool _reduceMotion = false;
  bool _showReactionPicker = false;

  /// BUT-1904. Local, and it lives HERE rather than in
  /// `SystemMessageWidget` because that one is a `StatelessWidget` and
  /// should stay one; this `State` survives the rebuild, since the row is
  /// keyed on the message id.
  bool _dismissRequested = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationDurationMedium,
    );
    _swipeAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _swipeController,
            curve: Curves.easeOut,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _swipeController.duration = Duration.zero;
    } else {
      _swipeController.duration = AppDimensions.animationDurationMedium;
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  bool get _isFromCurrentUser =>
      widget.message.isFromCurrentUser(widget.currentUserId);
  bool get _isSystemMessage => widget.message.isSystemMessage;
  bool get _isDuplicateBlocked =>
      widget.message.type == MessageType.duplicateBlocked;

  @override
  Widget build(BuildContext context) {
    // BUT-1904. Before everything below, which means the row gets none of the
    // bubble furniture: no sender side, no avatar, no timestamp, no delivery
    // ticks, no reactions (any written before the mark stay on the document and
    // are simply not drawn), no swipe-to-reply and no long-press menu. Its text
    // comes from the ARB, never from the document — a client-stamped row can
    // still be carrying its own, and that is exactly what must not surface.
    //
    // The long-press menu is dead for every message type today for an
    // unrelated reason, so the notice carries its own dismiss control instead
    // of borrowing one. It goes through the per-MESSAGE delete, which is why it
    // works the same in a group as in a direct message; what else can remove
    // the row depends on the conversation and is recorded in ADR-0009.
    //
    // Product framing on purpose: this lets the sender clear their own notice.
    // Do not describe it anywhere as satisfying a regulatory obligation —
    // whether this action is in scope for one has never been determined.
    if (_isDuplicateBlocked) {
      return RepaintBoundary(
        child: SystemMessageWidget(
          content: context.l10n.chatDuplicateBlocked,
          // Gated on OWNERSHIP as well as on the callback. The stream passes
          // the callback for every row, and `MessagingService` is what keeps
          // other people's notices off the screen — but that is a filter, not a
          // control, so a row that slipped past it would otherwise have drawn a
          // dismiss button firing a delete the rules refuse.
          //
          // Disabled after the first tap: the delete re-reads the document and
          // throws `ResourceNotFoundException` on the second, which would put
          // an error in front of the user for an action that worked. Reset when
          // the delete FAILS, or the only way to retry is to leave the chat.
          onDismiss:
              (widget.onDismissBlocked == null ||
                  !_isFromCurrentUser ||
                  _dismissRequested)
              ? null
              : () async {
                  setState(() => _dismissRequested = true);
                  final ok = await widget.onDismissBlocked!();
                  if (!ok && mounted) {
                    setState(() => _dismissRequested = false);
                  }
                },
          dismissSemanticsLabel: context.l10n.a11yDismissDuplicateNotice,
        ),
      );
    }
    if (_isSystemMessage) {
      return RepaintBoundary(child: _buildSystemMessage(context));
    }

    return RepaintBoundary(
      child: Semantics(
        label: context.l10n.a11yMessageSwipeToReply,
        container: true,
        child: GestureDetector(
          onHorizontalDragUpdate: widget.onReply != null
              ? _handleDragUpdate
              : null,
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
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    children: [
                      // Reply icon that appears during swipe
                      if (_dragExtent.abs() > 10)
                        Positioned(
                          left: _isFromCurrentUser ? 20 : null,
                          right: !_isFromCurrentUser ? 20 : null,
                          child: Opacity(
                            opacity: (_dragExtent.abs() / _swipeThreshold)
                                .clamp(0.0, 1.0),
                            child: Icon(
                              Icons.reply,
                              color: context.butleryColors.success,
                              size: AppDimensions.iconSizeL,
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
                                if (widget.showTimestamp)
                                  _buildTimestamp(context),
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
        ),
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
    return SystemMessageWidget(content: widget.message.content);
  }

  Widget _buildAvatar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondary.withValues(alpha: AppDimensions.opacityLight),
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
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.paddingS,
        bottom: AppDimensions.spacingXs,
      ),
      child: Text(
        widget.message.senderDisplayName,
        style: AppTextStyles.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return Column(
      crossAxisAlignment: _isFromCurrentUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Reaction picker overlay
        if (_showReactionPicker && widget.onReactionToggle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
            child: EmojiReactionPicker(
              onReactionSelected: (emoji) {
                widget.onReactionToggle?.call(emoji);
                setState(() => _showReactionPicker = false);
              },
            ),
          ),

        Semantics(
          label: context.l10n.a11yMessageLongPressOptions,
          button: true,
          child: GestureDetector(
            onTap: () {
              if (_showReactionPicker) {
                setState(() => _showReactionPicker = false);
              } else {
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              // Show reaction picker on long press if handler is available
              if (widget.onReactionToggle != null) {
                setState(() => _showReactionPicker = !_showReactionPicker);
              }
              widget.onLongPress?.call();
            },
            child: _buildBubble(context),
          ),
        ),

        // Reaction display below the bubble
        if (widget.message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
            child: EmojiReactionDisplay(
              reactions: widget.message.reactions,
              currentUserId: widget.currentUserId,
              onReactionTap: (emoji) => widget.onReactionToggle?.call(emoji),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final replyTo = widget.replyToMessage;
    if (replyTo == null) return const SizedBox.shrink();

    // BUT-1904: the same answer `ReplyBanner` gives, because this is the same
    // question. `displayContent` returns '' for a blocked row — it has no
    // `BuildContext`, so it has no truthful sentence to give — and unlike the
    // composer banner this path IS reachable: reply to a message, and the guard
    // marks it a moment later. Only the sender can see it, since the target is filtered
    // out of everyone else's list.
    return ReplyPreviewWidget(
      senderName: replyTo.senderDisplayName,
      content: replyTo.type == MessageType.duplicateBlocked
          ? context.l10n.chatDuplicateBlocked
          : replyTo.displayContent,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    return MessageContentBuilder.build(
      context: context,
      message: widget.message,
      isFromCurrentUser: _isFromCurrentUser,
      currentUserId: widget.currentUserId,
      onPollVote: widget.onPollVote,
      onPollClose: widget.onPollClose,
    );
  }

  Widget _buildMessageStatus(BuildContext context) {
    return MessageStatusWidget(status: widget.message.status);
  }

  /// The chat bubble itself, wrapped in [HoverableCard] so it gains a subtle
  /// hover affordance on web/desktop when interactive. The rest
  /// decoration reproduces the previous [StyledCard] exactly — a flat filled
  /// square with no shadow — so there's no visual change at rest.
  Widget _buildBubble(BuildContext context) {
    final restDecoration = BoxDecoration(
      color: _isFromCurrentUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
    );
    return HoverableCard(
      restDecoration: restDecoration,
      // Only imply clickability when the bubble actually does something on tap
      // (own tap handler, long-press, or a reaction toggle). A display-only
      // bubble defers the cursor, matching FriendCard/ShoppingListCard.
      enabled:
          widget.onTap != null ||
          widget.onLongPress != null ||
          widget.onReactionToggle != null,
      // Subtle shadow on hover (web/desktop) — fill + square corners unchanged.
      hoverDecoration: restDecoration.copyWith(boxShadow: AppShadows.subtle),
      child: Padding(
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
            if (_isFromCurrentUser) _buildMessageStatus(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    return MessageTimestampWidget(
      timestamp: widget.message.sentAt,
      isFromCurrentUser: _isFromCurrentUser,
    );
  }
}
