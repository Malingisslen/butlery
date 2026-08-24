/// Nuclear Message Stream Component - Real-time Message Display
/// Focused component handling ONLY message streaming and display logic that was
/// previously embedded in the massive ChatView. Implements clean separation of
/// concerns with real-time message updates.

import 'dart:async';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

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

  /// How many messages a page holds. Extracted because the divider's guard
  /// below has to be provably the SAME number as the query's limit — a guard
  /// keyed to a literal that drifts from the query is a guard that stops
  /// meaning anything without failing.
  static const int _pageLimit = 50;

  /// The query's cut-off: non-null for every member of a GROUP conversation,
  /// founders included, because that is what `firestore.rules` filters on and a
  /// reader that filters differently gets the whole query refused. It does NOT
  /// drive the divider — see [_joinedLaterAt], which is a narrower question.
  /// Resolved once per stream init; a conversation's `groupId`/`memberSince`
  /// never change under a member (BUT-1838).
  DateTime? _historyStart;

  /// When the "du gick med här" divider should render, which is a NARROWER
  /// question than "does this member have a cut-off": `historyStart` alone is
  /// non-null for founders too, because every founding member is stamped.
  DateTime? _joinedLaterAt;

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

  /// Completes when the ViewModel has a conversation, or when it gives up.
  ///
  /// A ChangeNotifier, not a Future, is what the ViewModel exposes — so this
  /// listens once rather than polling. It also completes on an ERROR: a
  /// conversation that cannot be loaded is not going to arrive, and hanging
  /// here would leave the chat on its spinner forever.
  Future<void> _awaitConversation(ChatViewModel viewModel) {
    final completer = Completer<void>();
    void listener() {
      if (viewModel.conversation != null || viewModel.hasError) {
        viewModel.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    viewModel.addListener(listener);
    // The value can already have arrived between the null check and this
    // subscription; check once more rather than wait for a notification that
    // has been and gone.
    if (viewModel.conversation != null || viewModel.hasError) {
      viewModel.removeListener(listener);
      return Future.value();
    }
    return completer.future;
  }

  Future<void> _initializeMessageStream() async {
    try {
      AppLogger.debug(
        'Initializing message stream for conversation: ${widget.conversationId}',
      );

      // The cut-off comes from the ViewModel, which owns the conversation —
      // this widget used to fetch it a SECOND time, which was both an extra
      // document read per chat open and a second place for the answer to come
      // from. Two resolution paths for one fact is how they disagree, and they
      // did: the widget's copy went through the user-scoped read and was null
      // for every group.
      //
      // WAITING for it is as load-bearing as reading it. `historyQueryStartFor` is
      // the cut-off `firestore.rules` enforces, and a query missing it can
      // return a message the rules refuse — which fails the WHOLE query, not
      // just that message. Three entry points construct this screen with no
      // conversation in hand (the create-group flow, the conversation list and
      // a shared-recipe card), so at `initState` the ViewModel is still
      // loading; opening the stream then would query unfiltered and hand a
      // late-joining member an error screen instead of their history.
      final viewModel = context.read<ChatViewModel>();
      if (viewModel.conversation == null) {
        await _awaitConversation(viewModel);
        if (!mounted) return;
      }
      _historyStart = viewModel.historyStart;
      _joinedLaterAt = viewModel.joinedLaterAt;

      // Load initial messages from MessagingService
      final messages = await _messagingService.getConversationMessagesPage(
        conversationId: widget.conversationId,
        historyStart: _historyStart,
        limit: _pageLimit,
      );

      // Set up real-time message stream
      _messageStream = _messagingService.getConversationMessages(
        conversationId: widget.conversationId,
        historyStart: _historyStart,
        limit: _pageLimit,
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
        // Only update if the message actually changed.
        //
        // BUT-1908: `metadata` belongs in this test. A poll vote changes
        // NOTHING else, so without it the tally and the hydration marker froze
        // at whatever the first render saw — and `_refreshMessages` runs this
        // same method, so pull-to-refresh did not repair it either. Only
        // reopening the chat did. That reproduced the ticket's own harm without
        // the cap being involved: the creator watches "0 röster" while members
        // vote, taps avsluta, and `closePoll` re-reads the message on its own
        // uncapped path and writes the real winner into the week's plan.
        //
        // `mapEquals` is SHALLOW, and `metadata['poll']` is a nested map
        // compared by identity, so on a poll message whose map was rebuilt it
        // answers false exactly as a bare `!=` would.
        // Replacing one element is cheap either way: `setState` already fires
        // unconditionally in the stream listener.
        if (_messages[index].content != newMsg.content ||
            _messages[index].status != newMsg.status ||
            _messages[index].readAt != newMsg.readAt ||
            !mapEquals(_messages[index].metadata, newMsg.metadata)) {
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
        historyStart: _historyStart,
        limit: _pageLimit,
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

  /// BUT-1908: `closePoll` can now REFUSE, and a refusal that nobody shows is
  /// the same silent failure the guard was built to replace. The viewmodel
  /// returns the Swedish sentence, or null when there is nothing to show.
  ///
  /// `mounted` is checked after the await because a snackbar outlives its
  /// route, and this widget can be disposed while the close is in flight.
  Future<void> _closePoll(ChatViewModel viewModel, String messageId) async {
    final problem = await viewModel.closePoll(messageId);
    if (!mounted || problem == null) return;
    SnackBarUtils.showError(context, problem);
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

    // "Du gick med här" divider at the top of the list — non-null exactly
    // when the current user joined a group conversation after it started.
    // The second condition is what stops the divider LYING, and the obvious
    // spelling of it does not work: comparing the oldest loaded message to the
    // join stamp is vacuous, because the query already filters on that same
    // value, so every loaded message satisfies it by construction.
    //
    // The page is the NEWEST [_pageLimit] messages. Only a SHORT page proves
    // the oldest one loaded is the first one after joining; a full page means
    // the join point is off-screen, and this widget has no load-more, so the
    // honest thing is to show no divider at all rather than one above
    // message fifty-one-from-the-end. Exactly [_pageLimit] hides it — failing
    // safe on the boundary rather than guessing.
    final showJoinedDivider =
        _joinedLaterAt != null &&
        _messages.isNotEmpty &&
        _messages.length < _pageLimit;

    return Consumer<ChatViewModel>(
      builder: (context, viewModel, child) {
        return RefreshIndicator(
          onRefresh: _refreshMessages,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingS,
            ),
            itemCount: _messages.length + (showJoinedDivider ? 1 : 0),
            itemBuilder: (context, rawIndex) {
              if (showJoinedDivider && rawIndex == 0) {
                return SystemMessageWidget(
                  content: context.l10n.chatJoinedHereDivider,
                );
              }
              final index = showJoinedDivider ? rawIndex - 1 : rawIndex;
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
                onPollClose: () => _closePoll(viewModel, message.id),
              );
            },
          ),
        );
      },
    );
  }
}
