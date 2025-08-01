/// Nuclear Facade for ChatView - Architectural Explosion Component
/// 
/// This facade coordinates the complete chat experience through focused components,
/// reducing the massive 1,648-line ChatView into a clean, maintainable architecture.
/// Each component handles a specific responsibility with clear interfaces.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/views/messaging/chat_view/chat_message_stream.dart';
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';

/// Clean ChatView facade coordinating specialized components
class ChatViewFacade extends StatefulWidget {
  final String conversationId;
  final Conversation? conversation;

  const ChatViewFacade({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  State<ChatViewFacade> createState() => _ChatViewFacadeState();
}

class _ChatViewFacadeState extends State<ChatViewFacade> {
  late final ChatActionHandler _actionHandler;

  @override
  void initState() {
    super.initState();
    _actionHandler = ChatActionHandler(
      conversationId: widget.conversationId,
      context: context,
    );
  }

  @override
  void dispose() {
    _actionHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        conversation: widget.conversation,
        onMenuAction: _actionHandler.handleMenuAction,
      ),
      body: Column(
        children: [
          // Message stream takes most of the space
          Expanded(
            child: ChatMessageStream(
              conversationId: widget.conversationId,
              onMessageAction: _actionHandler.handleMessageAction,
            ),
          ),
          
          // Input section at bottom
          ChatInputSection(
            conversationId: widget.conversationId,
            onSendMessage: _actionHandler.handleSendMessage,
            onAttachment: _actionHandler.handleAttachment,
          ),
        ],
      ),
    );
  }
}