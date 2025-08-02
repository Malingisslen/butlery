/// Nuclear Input Section Component - Message Composition Logic
/// 
/// Focused component handling ONLY message input and composition logic that was
/// previously scattered throughout the massive ChatView. Implements clean
/// message composition with attachment handling and typing indicators.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_colors.dart';

/// Clean input section with message composition and attachments
class ChatInputSection extends StatefulWidget {
  final String conversationId;
  final Function(String, {MessageType type}) onSendMessage;
  final Function(String) onAttachment;

  const ChatInputSection({
    super.key,
    required this.conversationId,
    required this.onSendMessage,
    required this.onAttachment,
  });

  @override
  State<ChatInputSection> createState() => _ChatInputSectionState();
}

class _ChatInputSectionState extends State<ChatInputSection> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  bool _showAttachments = false;

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
    if (isComposing != _isComposing) {
      if (mounted) {
        setState(() {
          _isComposing = isComposing;
        });
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showAttachments) {
      if (mounted) {
        setState(() {
          _showAttachments = false;
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
      AppLogger.debug('Sending message: $text');
      
      // Clear input immediately for responsive UX
      _textController.clear();
      if (mounted) {
        setState(() {
          _isComposing = false;
        });
      }

      // Send message through action handler
      await widget.onSendMessage(text, type: MessageType.text);
      
      AppLogger.success('Message sent successfully');
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      
      // Restore text on error
      _textController.text = text;
      if (mounted) {
        setState(() {
          _isComposing = true;
        });
      }
    }
  }

  void _toggleAttachments() {
    if (mounted) {
      setState(() {
        _showAttachments = !_showAttachments;
      });
    }
    
    if (_showAttachments) {
      _focusNode.unfocus();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment options (shown above input when active)
          if (_showAttachments)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: const Text('Bilagor: Recept, Meny, Handlingslista, Foto'),
              ),
            ),
          
          // Main input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              IconButton(
                onPressed: _toggleAttachments,
                icon: Icon(
                  _showAttachments ? Icons.close : Icons.attach_file,
                  color: _showAttachments 
                      ? AppColors.primary 
                      : AppColors.textSecondary,
                ),
                tooltip: _showAttachments 
                    ? 'Stäng' 
                    : 'Bilagor',
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
                  onPressed: _isComposing ? _handleSendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: _isComposing 
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
    );
  }
}