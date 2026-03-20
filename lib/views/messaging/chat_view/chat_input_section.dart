/// Nuclear Input Section Component - Message Composition Logic
/// Focused component handling ONLY message input and composition logic that was
/// previously scattered throughout the massive ChatView. Implements clean
/// message composition with attachment handling and typing indicators.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/widgets/messaging/image_picker_dialog.dart';
import 'package:butlery/widgets/messaging/reply_banner.dart';
import 'package:butlery/widgets/messaging/poll_creation_dialog.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Consolidated state class for ChatInputSection to reduce setState calls
class ChatInputState {
  final bool isComposing;
  final bool showAttachments;

  const ChatInputState({
    this.isComposing = false,
    this.showAttachments = false,
  });

  ChatInputState copyWith({
    bool? isComposing,
    bool? showAttachments,
  }) {
    return ChatInputState(
      isComposing: isComposing ?? this.isComposing,
      showAttachments: showAttachments ?? this.showAttachments,
    );
  }
}

/// Clean input section with message composition and attachments
class ChatInputSection extends StatefulWidget {
  final String conversationId;
  final Function(String, {MessageType type}) onSendMessage;
  final Function(String) onAttachment;
  final Message? replyToMessage;
  final VoidCallback? onCancelReply;
  final void Function(Map<String, dynamic> pollData)? onPollCreate;
  final String? currentUserId;

  const ChatInputSection({
    super.key,
    required this.conversationId,
    required this.onSendMessage,
    required this.onAttachment,
    this.replyToMessage,
    this.onCancelReply,
    this.onPollCreate,
    this.currentUserId,
  });

  @override
  State<ChatInputSection> createState() => _ChatInputSectionState();
}

class _ChatInputSectionState extends State<ChatInputSection> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ChatInputState _state = const ChatInputState();

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isComposing = _textController.text.trim().isNotEmpty;
    if (isComposing != _state.isComposing) {
      if (mounted) {
        setState(() {
          _state = _state.copyWith(isComposing: isComposing);
        });
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _state.showAttachments) {
      if (mounted) {
        setState(() {
          _state = _state.copyWith(showAttachments: false);
        });
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      AppLogger.info(
          '📤 [ChatInputSection] Starting send for message: "${text.substring(0, text.length > 20 ? 20 : text.length)}..."');
      AppLogger.debug('📤 [ChatInputSection] Full message content: "$text"');
      AppLogger.debug(
          '📤 [ChatInputSection] Conversation ID: ${widget.conversationId}');

      // Send message through action handler FIRST
      AppLogger.debug('📤 [ChatInputSection] Calling action handler...');
      await widget.onSendMessage(text, type: MessageType.text);

      AppLogger.success(
          '✅ [ChatInputSection] Message send completed successfully');

      // Only clear input AFTER successful send
      AppLogger.debug(
          '📤 [ChatInputSection] Clearing input after successful send...');
      _textController.clear();
      if (mounted) {
        setState(() {
          _state = _state.copyWith(isComposing: false);
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ [ChatInputSection] Failed to send message', e);
      AppLogger.error('❌ [ChatInputSection] Stack trace: $stackTrace');

      // Keep text in field so user can retry
      // Show error to user
      if (mounted) {
        SnackBarUtils.showError(context, context.l10n.chatCouldNotSendMessage);
      }
    }
  }

  void _toggleAttachments() {
    if (mounted) {
      setState(() {
        _state = _state.copyWith(showAttachments: !_state.showAttachments);
      });
    }

    if (_state.showAttachments) {
      _focusNode.unfocus();
    }
  }

  Future<void> _handleImagePick() async {
    try {
      // Show image picker dialog
      final source = await showImagePickerDialog(context);

      if (source != null && mounted) {
        AppLogger.info('Image source selected: $source');

        // Trigger attachment handler with photo type and source
        await widget.onAttachment('photo:${source.name}');
      }
    } catch (e) {
      AppLogger.error('Failed to pick image', e);
    }
  }

  Future<void> _handlePollCreate() async {
    if (widget.currentUserId == null || widget.onPollCreate == null) return;
    try {
      final poll = await showDialog<Poll>(
        context: context,
        builder: (ctx) => PollCreationDialog(creatorId: widget.currentUserId!),
      );
      if (poll != null && mounted) {
        widget.onPollCreate!(poll.toMap());
      }
    } catch (e) {
      AppLogger.error('Failed to create poll', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: cs.onSurfaceVariant
                .withValues(alpha: AppDimensions.opacityMediumLight),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply banner (shown when replying to a message)
          if (widget.replyToMessage != null && widget.onCancelReply != null)
            ReplyBanner(
              message: widget.replyToMessage!,
              onCancelReply: widget.onCancelReply!,
            ),

          // Input section
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attachment options (shown above input when active)
                if (_state.showAttachments)
                  Container(
                    margin:
                        const EdgeInsets.only(bottom: AppDimensions.spacingS),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingL),
                      child: Text(context.l10n.chatAttachmentTypes),
                    ),
                  ),

                // Main input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Image button
                    IconButton(
                      onPressed: _handleImagePick,
                      icon: const Icon(Icons.image_outlined),
                      color: context.butleryColors.success,
                      tooltip: context.l10n.chatSendImage,
                    ),

                    // Poll button
                    if (widget.onPollCreate != null)
                      IconButton(
                        onPressed: _handlePollCreate,
                        icon: const Icon(Icons.poll_outlined),
                        color: cs.onSurfaceVariant,
                        tooltip: context.l10n.pollCreate,
                      ),

                    // Attachment button
                    IconButton(
                      onPressed: _toggleAttachments,
                      icon: Icon(
                        _state.showAttachments
                            ? Icons.close
                            : Icons.attach_file,
                        color: _state.showAttachments
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      tooltip: _state.showAttachments
                          ? context.l10n.commonClose
                          : context.l10n.chatAttachments,
                    ),

                    // Text input field
                    Expanded(
                      child: MessageInputField(
                        controller: _textController,
                        focusNode: _focusNode,
                        hintText: context.l10n.chatWriteMessage,
                        onSubmitted: _handleSendMessage,
                      ),
                    ),

                    // Send button
                    AnimatedContainer(
                      duration: AppDimensions.animationDurationMedium,
                      child: IconButton(
                        onPressed:
                            _state.isComposing ? _handleSendMessage : null,
                        icon: Icon(
                          Icons.send,
                          color: _state.isComposing
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        tooltip: context.l10n.chatSend,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
