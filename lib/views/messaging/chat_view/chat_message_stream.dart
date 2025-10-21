/// Nuclear Message Stream Component - Real-time Message Display
/// 
/// Focused component handling ONLY message streaming and display logic that was
/// previously embedded in the massive ChatView. Implements clean separation of
/// concerns with optimized message rendering and real-time updates.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Optimized message stream with real-time updates and pagination
class ChatMessageStream extends StatefulWidget {
  final String conversationId;
  final Function(Message, String) onMessageAction;

  const ChatMessageStream({
    super.key,
    required this.conversationId,
    required this.onMessageAction,
  });

  @override
  State<ChatMessageStream> createState() => _ChatMessageStreamState();
}

class _ChatMessageStreamState extends State<ChatMessageStream> {
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final MessagingService _messagingService = ServiceLocator.get<MessagingService>();
  bool _isLoading = true;
  String? _error;
  Stream<List<Message>>? _messageStream;

  @override
  void initState() {
    super.initState();
    _initializeMessageStream();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeMessageStream() async {
    try {
      AppLogger.debug('Initializing message stream for conversation: ${widget.conversationId}');
      
      // Load initial messages from MessagingService
      final messages = await _messagingService.getConversationMessagesPage(
        conversationId: widget.conversationId,
        limit: 50,
      );
      
      // Set up real-time message stream
      _messageStream = _messagingService.getConversationMessages(
        conversationId: widget.conversationId,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
          _error = null;
        });
        
        // Listen to real-time updates
        _messageStream?.listen((newMessages) {
          if (mounted) {
            setState(() {
              _messages.clear();
              _messages.addAll(newMessages);
            });
            _scrollToBottom();
          }
        });

        // Auto-scroll to bottom for new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      AppLogger.error('Failed to initialize message stream', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Ett fel uppstod';
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppDimensions.animationDurationCommon,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _refreshMessages() async {
    try {
      // Refresh messages from MessagingService
      final messages = await _messagingService.getConversationMessagesPage(
        conversationId: widget.conversationId,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _error = null;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
      if (mounted) {
        setState(() {
          _error = 'Ett fel uppstod';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingStates.buildLoadingState(
        context,
        variant: LoadingVariant.spinner,
        message: 'Laddar meddelanden...',
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: AppDimensions.spacingL),
            ActionButtons.actionButton(
              context,
              label: 'Försök igen',
              onPressed: _refreshMessages,
              icon: Icons.refresh,
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return EmptyStates.buildEmptyState(
        context,
        variant: EmptyStateVariant.generic,
        title: 'Inga meddelanden än',
        subtitle: 'Skicka ett meddelande för att starta konversationen',
      );
    }

    return Consumer<ChatViewModel>(
      builder: (context, viewModel, child) {
        return RefreshIndicator(
          onRefresh: _refreshMessages,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final previousMessage = index > 0 ? _messages[index - 1] : null;

              // Find the reply-to message if this message is a reply
              Message? replyToMessage;
              if (message.isReply && message.replyToMessageId != null) {
                try {
                  replyToMessage = _messages.firstWhere(
                    (m) => m.id == message.replyToMessageId,
                  );
                } catch (e) {
                  // Reply message not found in current messages
                  AppLogger.warning('Reply message not found: ${message.replyToMessageId}');
                }
              }

              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                currentUserId: viewModel.currentUserId ?? '',
                replyToMessage: replyToMessage,
                showAvatar: viewModel.shouldShowAvatar(message, previousMessage),
                onTap: () => AppLogger.debug('Message tapped: ${message.id}'),
                onLongPress: () => widget.onMessageAction(message, 'menu'),
                onReply: () => viewModel.setReplyToMessage(message),
              );
            },
          ),
        );
      },
    );
  }
}