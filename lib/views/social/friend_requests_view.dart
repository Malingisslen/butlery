// lib/views/social/friend_requests_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Import focused components
import 'package:butlery/views/social/friend_requests/friend_requests_header.dart';
import 'package:butlery/views/social/friend_requests/incoming_requests_tab.dart';
import 'package:butlery/views/social/friend_requests/sent_requests_tab.dart';
import 'package:butlery/views/social/friend_requests/friend_request_actions_refactored.dart';

class FriendRequestsView extends StatelessWidget {
  const FriendRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<FriendsViewModel>(),
      child: const _FriendRequestsViewContent(),
    );
  }
}

class _FriendRequestsViewContent extends StatefulWidget {
  const _FriendRequestsViewContent();

  @override
  State<_FriendRequestsViewContent> createState() =>
      _FriendRequestsViewContentState();
}

class _FriendRequestsViewContentState extends State<_FriendRequestsViewContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIncoming = {};
  final Set<String> _selectedSent = {};
  late final FriendRequestActions _actions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _actions = FriendRequestActions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<FriendsViewModel>();
      viewModel.refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _actions.dispose();
    super.dispose();
  }

  void _clearSelection() {
    setState(() {
      _selectedIncoming.clear();
      _selectedSent.clear();
    });
  }

  void _onIncomingSelectionChanged(String requestId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIncoming.add(requestId);
      } else {
        _selectedIncoming.remove(requestId);
      }
    });
  }

  void _onSentSelectionChanged(String requestId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSent.add(requestId);
      } else {
        _selectedSent.remove(requestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FriendsViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: FriendRequestsHeader.buildAppBar(
          context,
          viewModel,
          _tabController,
          _clearSelection,
          _selectedIncoming,
          _selectedSent,
          () => _handleBatchAccept(viewModel),
          () => _handleBatchReject(viewModel),
          () => _handleCancelSelected(viewModel),
        ),
        body: Column(
          children: [
            FriendRequestsHeader.buildErrorDisplay(context, viewModel),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  IncomingRequestsTab.build(
                    context,
                    viewModel,
                    _selectedIncoming,
                    _onIncomingSelectionChanged,
                    _clearSelection,
                  ),
                  SentRequestsTab.build(
                    context,
                    viewModel,
                    _selectedSent,
                    _onSentSelectionChanged,
                    _clearSelection,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _actions.buildFloatingActionButton(
          context,
          _tabController,
          _selectedIncoming,
          () => _handleBatchAccept(viewModel),
        ),
      ),
    );
  }

  Future<void> _handleBatchAccept(FriendsViewModel viewModel) async {
    if (_selectedIncoming.isEmpty) return;

    await _actions.acceptMultipleRequests(
      context,
      _selectedIncoming.toList(),
      _clearSelection,
    );
  }

  Future<void> _handleBatchReject(FriendsViewModel viewModel) async {
    if (_selectedIncoming.isEmpty) return;

    await _actions.rejectMultipleRequests(
      context,
      _selectedIncoming.toList(),
      _clearSelection,
    );
  }

  Future<void> _handleCancelSelected(FriendsViewModel viewModel) async {
    if (_selectedSent.isEmpty) return;

    await _actions.cancelMultipleSentRequests(
      context,
      _selectedSent.toList(),
      _clearSelection,
    );
  }
}
