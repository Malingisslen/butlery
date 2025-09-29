/// Nuclear Message Stream Component - Real-time Message Display
/// 
/// Focused component handling ONLY message streaming and display logic that was
/// previously embedded in the massive ChatView. Implements clean separation of
/// concerns with optimized message rendering and real-time updates.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
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

    return RefreshIndicator(
      onRefresh: _refreshMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return Padding(
            key: ValueKey(message.id),
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
              child: Text(message.content),
            ),
          );
        },
      ),
    );
  }
}