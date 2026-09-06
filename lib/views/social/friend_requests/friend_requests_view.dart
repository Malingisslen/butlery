// lib/views/social/friend_requests/friend_requests_view.dart
//
// REFACTORED: Extracted helper classes to separate files for better maintainability
// - FriendRequestActions -> friend_request_actions.dart
// - FriendRequestCard -> friend_request_card.dart
// - HeaderBuilder, TabBuilders -> friend_request_builders.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'package:butlery/core/providers/application_provider.dart';

// ViewModels
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/layout_components.dart';

// Local extracted components
import 'package:butlery/views/social/friend_requests/friend_request_actions.dart';
import 'package:butlery/views/social/friend_requests/friend_request_builders.dart';

/// Main friend requests view - thin facade coordinating extracted components
class FriendRequestsView extends StatefulWidget {
  const FriendRequestsView({super.key});

  @override
  State<FriendRequestsView> createState() => _FriendRequestsViewState();
}

class _FriendRequestsViewState extends State<FriendRequestsView> {
  late final FriendsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<FriendsViewModel>();
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

  /// Per VIEW, not per account: it stops a second press on this screen, not a
  /// batch started from another device.
  bool _batchRunning = false;

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

  /// Drops the whole selection. A batch reconciles it instead, via
  /// [_reconcileSelection].
  void _clearSelection() {
    if (mounted) {
      setState(() {
        _selectedIncoming.clear();
        _selectedSent.clear();
      });
    }
  }

  /// Drops what the batch wrote, and anything that is no longer open: a
  /// request cancelled from another device stops being a card but would
  /// otherwise stay counted by the controls and fail every retry. Runs on
  /// every batch, including one where nothing landed.
  void _reconcileSelection(
    Set<String> selection,
    List<String> landed,
    Iterable<FriendRequest> stillOpen,
  ) {
    if (!mounted) return;
    final open = stillOpen.map((request) => request.id).toSet();
    setState(() {
      selection
        ..removeAll(landed)
        ..retainWhere(open.contains);
    });
  }

  /// Locks the batch controls from the moment the user CONFIRMS — locking at
  /// the tap would spin the button while the confirmation dialog is still
  /// asking. The flag is cleared in a `finally` so a throw cannot leave the
  /// controls locked for the rest of the screen.
  Future<void> _runLocked(
    Future<void> Function(VoidCallback onConfirmed) batch,
  ) async {
    if (_batchRunning) return;
    try {
      await batch(() {
        if (mounted) setState(() => _batchRunning = true);
      });
    } finally {
      if (mounted && _batchRunning) setState(() => _batchRunning = false);
    }
  }

  void _onIncomingSelectionChanged(String requestId, bool selected) {
    if (mounted) {
      setState(() {
        if (selected) {
          _selectedIncoming.add(requestId);
        } else {
          _selectedIncoming.remove(requestId);
        }
      });
    }
  }

  void _onSentSelectionChanged(String requestId, bool selected) {
    if (mounted) {
      setState(() {
        if (selected) {
          _selectedSent.add(requestId);
        } else {
          _selectedSent.remove(requestId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FriendsViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: FriendRequestsHeaderBuilder.buildAppBar(
          context,
          viewModel,
          _tabController,
          _clearSelection,
          _selectedIncoming,
          _selectedSent,
          () => _handleBatchAccept(viewModel),
          () => _handleBatchReject(viewModel),
          () => _handleCancelSelected(viewModel),
          batchRunning: _batchRunning,
        ),
        body: SafeArea(
          // ✅ RESPONSIVE: Center and constrain content on large screens
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: LayoutComponents.valueFor(
                  context: context,
                  mobile: double.infinity,
                  tablet: 700,
                  desktop: 800,
                ),
              ),
              child: Column(
                children: [
                  LayoutComponents.offlineIndicator(),
                  FriendRequestsHeaderBuilder.buildErrorDisplay(
                    context,
                    viewModel,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        IncomingRequestsTabBuilder.build(
                          context,
                          viewModel,
                          _selectedIncoming,
                          _onIncomingSelectionChanged,
                          _clearSelection,
                        ),
                        SentRequestsTabBuilder.build(
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
            ),
          ),
        ),
        floatingActionButton: _actions.buildFloatingActionButton(
          context,
          _tabController,
          _selectedIncoming,
          () => _handleBatchAccept(viewModel),
          batchRunning: _batchRunning,
        ),
      ),
    );
  }

  Future<void> _handleBatchAccept(FriendsViewModel viewModel) async {
    if (_selectedIncoming.isEmpty) return;

    await _runLocked(
      (onConfirmed) => _actions.acceptMultipleRequests(
        context,
        viewModel,
        _selectedIncoming.toList(),
        (landed) => _reconcileSelection(
          _selectedIncoming,
          landed,
          viewModel.incomingRequests,
        ),
        onConfirmed: onConfirmed,
      ),
    );
  }

  Future<void> _handleBatchReject(FriendsViewModel viewModel) async {
    if (_selectedIncoming.isEmpty) return;

    await _runLocked(
      (onConfirmed) => _actions.rejectMultipleRequests(
        context,
        viewModel,
        _selectedIncoming.toList(),
        (landed) => _reconcileSelection(
          _selectedIncoming,
          landed,
          viewModel.incomingRequests,
        ),
        onConfirmed: onConfirmed,
      ),
    );
  }

  Future<void> _handleCancelSelected(FriendsViewModel viewModel) async {
    if (_selectedSent.isEmpty) return;

    await _runLocked(
      (onConfirmed) => _actions.cancelMultipleSentRequests(
        context,
        viewModel,
        _selectedSent.toList(),
        (landed) =>
            _reconcileSelection(_selectedSent, landed, viewModel.sentRequests),
        onConfirmed: onConfirmed,
      ),
    );
  }
}
