/// Nuclear Message Stream Component - Real-time Message Display
/// Focused component handling ONLY message streaming and display logic that was
/// previously embedded in the massive ChatView. Implements clean separation of
/// concerns with real-time message updates.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Message stream widget with real-time updates (50 message limit)
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
  final MessagingService _messagingService =
      ServiceLocator.get<MessagingService>();
  bool _isLoading = true;
  String? _error;
  Stream<List<Message>>? _messageStream;
  StreamSubscription<List<Message>>? _messageStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMessageStream();
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeMessageStream() async {
    try {
      AppLogger.debug(
        'Initializing message stream for conversation: ${widget.conversationId}',
      );

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
        _messageStreamSubscription = _messageStream?.listen(
          (newMessages) {
            if (mounted) {
              setState(() {
                _updateMessagesIncremental(newMessages);
              });
              _scrollToBottom();
            }
          },
          onError: (Object error) {
            AppLogger.error('Message stream error', error);
            if (mounted) {
              setState(() {
                _error = context.l10n.errorGeneric;
              });
            }
          },
        );

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
          _error = context.l10n.errorGeneric;
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

  /// Incrementally update messages list (O(m+n) instead of O(n) clear/rebuild)
  void _updateMessagesIncremental(List<Message> newMessages) {
    final newMessageIds = newMessages.map((m) => m.id).toSet();
    final currentMessageIds = _messages.map((m) => m.id).toSet();

    // Add new messages that don't exist
    final toAdd = newMessages.where((m) => !currentMessageIds.contains(m.id));
    _messages.addAll(toAdd);

    // Update existing messages if content changed
    for (var newMsg in newMessages) {
      final index = _messages.indexWhere((m) => m.id == newMsg.id);
      if (index != -1) {
        // Only update if message content actually changed
        if (_messages[index].content != newMsg.content ||
            _messages[index].status != newMsg.status ||
            _messages[index].readAt != newMsg.readAt) {
          _messages[index] = newMsg;
        }
      }
    }

    // Remove messages that no longer exist
    _messages.removeWhere((m) => !newMessageIds.contains(m.id));

    // Sort by sentAt timestamp (most recent at bottom)
    _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
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
          _updateMessagesIncremental(messages);
          _error = null;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
      if (mounted) {
        setState(() {
          _error = context.l10n.errorGeneric;
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
        message: context.l10n.chatLoadingMessages,
      );
    }

    if (_error != null) {
      return StateWidget.error(
        message: _error!,
        onAction: _refreshMessages,
      );
    }

    if (_messages.isEmpty) {
      return EmptyStates.buildEmptyState(
        context,
        variant: EmptyStateVariant.generic,
        title: context.l10n.chatNoMessages,
        subtitle: context.l10n.chatSendToStartConversation,
      );
    }

    return Consumer<ChatViewModel>(
      builder: (context, viewModel, child) {
        return RefreshIndicator(
          onRefresh: _refreshMessages,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingS,
            ),
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
                  AppLogger.warning(
                    'Reply message not found: ${message.replyToMessageId}',
                  );
                }
              }

              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                currentUserId: viewModel.currentUserId.orEmpty(),
                replyToMessage: replyToMessage,
                showAvatar: viewModel.shouldShowAvatar(
                  message,
                  previousMessage,
                ),
                // BUT-948 exception: long-press opens the message action menu
                // (contextual), not multi-select — messaging convention.
                onLongPress: () => widget.onMessageAction(message, 'menu'),
                onReply: () => viewModel.setReplyToMessage(message),
                onPollVote: (optionId) =>
                    viewModel.votePoll(message.id, optionId),
                onPollClose: () => viewModel.closePoll(message.id),
              );
            },
          ),
        );
      },
    );
  }
}
