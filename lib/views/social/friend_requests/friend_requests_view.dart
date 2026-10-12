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
import 'package:butlery/widgets/common/indicators/batch_activity_bar.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
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

class _FriendRequestsViewContentState
    extends State<_FriendRequestsViewContent> {
  /// "Välj": the rows take a checkbox and the batch actions appear.
  bool _selecting = false;
  final Set<String> _selectedIncoming = {};
  final Set<String> _selectedSent = {};
  late final FriendRequestActions _actions;

  /// Per VIEW, not per account: it stops a second press on this screen, not a
  /// batch started from another device.
  bool _batchRunning = false;

  @override
  void initState() {
    super.initState();
    _actions = FriendRequestActions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<FriendsViewModel>();
      viewModel.refresh();
    });
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  /// Leaving "Välj" drops both selections; a refresh keeps them (BUT-2042) and
  /// a batch reconciles them via [_reconcileSelection].
  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) {
        _selectedIncoming.clear();
        _selectedSent.clear();
      }
    });
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

  /// After a refresh, keeps what is still open and drops what was answered or
  /// cancelled elsewhere, so the controls never count a card that is gone.
  void _pruneAfterRefresh(FriendsViewModel viewModel) {
    _reconcileSelection(
      _selectedIncoming,
      const [],
      viewModel.incomingRequests,
    );
    _reconcileSelection(_selectedSent, const [], viewModel.sentRequests);
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
    final hasRows =
        viewModel.incomingRequests.isNotEmpty ||
        viewModel.sentRequests.isNotEmpty;
    final hasSelection =
        _selectedIncoming.isNotEmpty || _selectedSent.isNotEmpty;
    // "Välj" is only offered while there are rows, so select mode must not
    // outlive the last one.
    if (_selecting && !hasRows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selecting) setState(() => _selecting = false);
      });
    }

    return ButleryPage.undersida(
      title: context.l10n.socialFriendRequestsTitle,
      backTo: context.l10n.socialFriendsAndGroups,
      ruleUnderBar: false,
      actions: [
        if (hasRows)
          TextButton(
            onPressed: _toggleSelecting,
            child: Text(
              _selecting
                  ? context.l10n.commonDone
                  : context.l10n.socialRequestsSelect,
            ),
          ),
      ],
      // The bulk actions take the tab bar's place while something is chosen.
      bottomNavigationBar: hasSelection
          ? _buildBulkBar(context, viewModel)
          : null,
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          // Gated on the batch rather than on a selection, so it survives a
          // cleared selection, which takes every batch control off screen
          // (BUT-2041).
          BatchActivityBar(active: _batchRunning),
          FriendRequestsHeaderBuilder.buildErrorDisplay(context, viewModel),
          Expanded(
            child: FriendRequestsListBuilder.build(
              context,
              viewModel,
              _selectedIncoming,
              _selectedSent,
              selecting: _selecting,
              onIncomingChanged: _onIncomingSelectionChanged,
              onSentChanged: _onSentSelectionChanged,
              onRefreshed: () => _pruneAfterRefresh(viewModel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBar(BuildContext context, FriendsViewModel viewModel) {
    final l10n = context.l10n;
    return BottomActionContainer(
      child: Row(
        children: [
          if (_selectedIncoming.isNotEmpty) ...[
            Expanded(
              child: HeroButton(
                key: const ValueKey('friendRequests.bulkAccept'),
                label: l10n.socialAcceptCount(_selectedIncoming.length),
                // A null onPressed is what refuses a second press while a
                // batch runs; what SAYS so is `BatchActivityBar`.
                onPressed: _batchRunning
                    ? null
                    : () => _handleBatchAccept(viewModel),
                expand: true,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: ActionButtons.outlinedButton(
                context,
                key: const ValueKey('friendRequests.bulkDecline'),
                label: l10n.socialDeclineCount(_selectedIncoming.length),
                onPressed: _batchRunning
                    ? null
                    : () => _handleBatchReject(viewModel),
              ),
            ),
          ],
          if (_selectedIncoming.isNotEmpty && _selectedSent.isNotEmpty)
            const SizedBox(width: AppDimensions.space12),
          if (_selectedSent.isNotEmpty)
            Expanded(
              child: ActionButtons.outlinedButton(
                context,
                key: const ValueKey('friendRequests.bulkCancel'),
                label: l10n.socialCancelCount(_selectedSent.length),
                onPressed: _batchRunning
                    ? null
                    : () => _handleCancelSelected(viewModel),
              ),
            ),
        ],
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
