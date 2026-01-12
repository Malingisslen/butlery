/// Nuclear Input Section Component - Message Composition Logic
/// Focused component handling ONLY message input and composition logic that was
/// previously scattered throughout the massive ChatView. Implements clean
/// message composition with attachment handling and typing indicators.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/widgets/messaging/image_picker_dialog.dart';
import 'package:butlery/widgets/messaging/reply_banner.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

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

  const ChatInputSection({
    super.key,
    required this.conversationId,
    required this.onSendMessage,
    required this.onAttachment,
    this.replyToMessage,
    this.onCancelReply,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde inte skicka meddelandet. Försök igen.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: AppColors.textMedium.withValues(alpha: AppDimensions.opacityMediumLight),
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
                      child: const Text(
                          'Bilagor: Recept, Meny, Handlingslista, Foto'),
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
                      color: AppColors.success,
                      tooltip: 'Skicka bild',
                    ),

                    // Attachment button
                    IconButton(
                      onPressed: _toggleAttachments,
                      icon: Icon(
                        _state.showAttachments
                            ? Icons.close
                            : Icons.attach_file,
                        color: _state.showAttachments
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      tooltip: _state.showAttachments ? 'Stäng' : 'Bilagor',
                    ),

                    // Text input field
                    Expanded(
                      child: MessageInputField(
                        controller: _textController,
                        focusNode: _focusNode,
                        hintText: 'Skriv ett meddelande...',
                        onSubmitted: _handleSendMessage,
                      ),
                    ),

                    // Send button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        onPressed:
                            _state.isComposing ? _handleSendMessage : null,
                        icon: Icon(
                          Icons.send,
                          color: _state.isComposing
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        tooltip: 'Skicka',
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
