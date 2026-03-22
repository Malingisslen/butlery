/// Nuclear Facade for ChatView - Architectural Explosion Component
/// This facade coordinates the complete chat experience through focused components,
/// reducing the massive 1,648-line ChatView into a clean, maintainable architecture.
/// Each component handles a specific responsibility with clear interfaces.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_message_stream.dart';
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';
import 'package:butlery/widgets/messaging/typing_indicator.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

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
  late final ChatViewModel _viewModel;
  late final ChatActionHandler _actionHandler;

  @override
  void initState() {
    super.initState();

    // Try to get PresenceService (optional dependency)
    PresenceService? presenceService;
    try {
      presenceService = ServiceLocator.get<PresenceService>();
    } catch (e) {
      // PresenceService not registered yet - typing indicators will be disabled
    }

    // Initialize ChatViewModel
    _viewModel = ChatViewModel(
      messagingService: ServiceLocator.get<MessagingService>(),
      conversationId: widget.conversationId,
      initialConversation: widget.conversation,
      presenceService: presenceService,
    );

    // Initialize action handler
    _actionHandler = ChatActionHandler(
      conversationId: widget.conversationId,
      context: context,
      onReplyToMessage: _viewModel.setReplyToMessage,
    );
  }

  @override
  void dispose() {
    _actionHandler.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kill switch: gate messaging behind feature flag
    final featureFlags = ServiceLocator.get<FeatureFlagService>();
    if (!featureFlags.isEnabled(FeatureFlags.enableMessaging)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.chatTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: Text(
              'Meddelandefunktionen är tillfälligt inaktiverad.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: ChatAppBar(
              conversation: viewModel.conversation ?? widget.conversation,
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

                // Typing indicator (shows when someone is typing)
                if (viewModel.hasTypingUsers)
                  TypingIndicator(
                    typingUserNames: viewModel.typingUserNames,
                  ),

                // Input section or friendship blocked banner
                if (viewModel.isFriendshipBlocked)
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingL),
                    child: Text(
                      context.l10n.chatCannotMessageNonFriend,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ChatInputSection(
                    conversationId: widget.conversationId,
                    onSendMessage: _actionHandler.handleSendMessage,
                    onAttachment: _actionHandler.handleAttachment,
                    replyToMessage: viewModel.replyToMessage,
                    onCancelReply: viewModel.clearReplyToMessage,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
