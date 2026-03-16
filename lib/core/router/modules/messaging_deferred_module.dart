import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';

// Deferred imports for messaging views
import 'package:butlery/views/messaging/conversations_list_view.dart'
    deferred as conversations;
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart'
    deferred as chat_view;

/// Deferred module for messaging related views
/// This module defers loading of:
/// - ConversationsListView
/// - ChatViewFacade
class MessagingDeferredModule implements DeferredModule {
  bool _isLoaded = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Set<String> get handledRoutes => {
        Routes.messages,
        Routes.chat,
      };

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    // Messaging depends on Social module being loaded
    // Ensure Social is loaded first if it's registered
    if (DeferredModuleLoader.isRegistered('social') &&
        !DeferredModuleLoader.isLoaded('social')) {
      await DeferredModuleLoader.ensureLoaded('social');
    }

    // Load messaging view libraries in parallel
    await Future.wait([
      conversations.loadLibrary(),
      chat_view.loadLibrary(),
    ]);

    _isLoaded = true;
  }

  @override
  Widget buildRoute(String routeName, RouteSettings settings) {
    switch (routeName) {
      case Routes.messages:
        // ignore: prefer_const_constructors
        return _ConversationsProviderWrapper(
          child: conversations.ConversationsListView(),
        );

      case Routes.chat:
        final conversationId = settings.arguments as String?;
        if (conversationId == null) {
          throw ArgumentError('Conversation ID argument missing for chat');
        }
        return chat_view.ChatViewFacade(conversationId: conversationId);

      default:
        throw ArgumentError('Unknown messaging route: $routeName');
    }
  }
}

/// Wrapper that owns the ConversationsViewModel lifecycle.
class _ConversationsProviderWrapper extends StatefulWidget {
  final Widget child;

  const _ConversationsProviderWrapper({required this.child});

  @override
  State<_ConversationsProviderWrapper> createState() =>
      _ConversationsProviderWrapperState();
}

class _ConversationsProviderWrapperState
    extends State<_ConversationsProviderWrapper> {
  late final ConversationsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<ConversationsViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: widget.child,
    );
  }
}
