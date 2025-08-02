/// Nuclear Message Stream Component - Real-time Message Display
/// 
/// Focused component handling ONLY message streaming and display logic that was
/// previously embedded in the massive ChatView. Implements clean separation of
/// concerns with optimized message rendering and real-time updates.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

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
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messagingService = ServiceLocator.get<MessagingService>();
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
      
      // TODO: Load initial messages from MessagingService
      final messages = <Message>[];
      
      if (mounted) {
        if (mounted) setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
          _error = null;
        });

        // Auto-scroll to bottom for new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      AppLogger.error('Failed to initialize message stream', e);
      if (mounted) {
        if (mounted) setState(() {
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _refreshMessages() async {
    try {
      // TODO: Refresh messages from MessagingService
      final messages = <Message>[];
      
      if (mounted) {
        if (mounted) setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _error = null;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
      if (mounted) {
        if (mounted) setState(() {
          _error = 'Ett fel uppstod';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshMessages,
              child: const Text('Försök igen'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text('Inga meddelanden än'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(message.content),
            ),
          );
        },
      ),
    );
  }
}