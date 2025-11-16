// lib/views/social/friend_requests_view.dart

// ==================== IMPORTS ====================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Models
import 'package:butlery/models/friend_request.dart';

// Theme
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// ViewModels
import 'package:butlery/viewmodels/friends_viewmodel.dart';

// Widgets
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';

// ==================== MAIN VIEW CLASSES ====================

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
  late final _FriendRequestActions _actions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _actions = _FriendRequestActions();

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
    if (mounted) {
      setState(() {
        _selectedIncoming.clear();
        _selectedSent.clear();
      });
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
        appBar: _FriendRequestsHeaderBuilder.buildAppBar(
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
            _FriendRequestsHeaderBuilder.buildErrorDisplay(context, viewModel),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _IncomingRequestsTabBuilder.build(
                    context,
                    viewModel,
                    _selectedIncoming,
                    _onIncomingSelectionChanged,
                    _clearSelection,
                  ),
                  _SentRequestsTabBuilder.build(
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

// ==================== FRIEND REQUEST ACTIONS ====================

/// Refactored FriendRequestActions using BaseActionHandler
///
/// This class provides standardized friend request operations with:
/// - Consistent batch operations with confirmation
/// - Proper error handling and user feedback
/// - Safe context handling for UI operations
/// - Standardized dialog patterns
class _FriendRequestActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'FriendRequestActions';

  // ===== UI COMPONENTS =====

  /// Build floating action button for batch operations
  Widget? buildFloatingActionButton(
    BuildContext context,
    TabController tabController,
    Set<String> selectedIncoming,
    VoidCallback onBatchAccept,
  ) {
    if (!validateContext(context)) return null;

    if (tabController.index == 0 && selectedIncoming.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: () => acceptMultipleRequests(
          context,
          selectedIncoming.toList(),
          onBatchAccept,
        ),
        icon: const Icon(Icons.check_circle),
        label: Text('Acceptera ${selectedIncoming.length}'),
        backgroundColor: AppColors.success,
      );
    }
    return null;
  }

  // ===== INDIVIDUAL REQUEST OPERATIONS =====

  /// Accept a single friend request
  Future<void> acceptFriendRequest(
    BuildContext context,
    String requestId,
    String senderName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'accepting friend request')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate accepting friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: 'Vänskapsförfrågan från $senderName accepterad',
      errorMessage: 'Kunde inte acceptera vänskapsförfrågan',
      metadata: {
        'request_id': requestId,
        'sender_name': senderName,
        'action': 'accept_single',
      },
    );
  }

  /// Reject a single friend request
  Future<void> rejectFriendRequest(
    BuildContext context,
    String requestId,
    String senderName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'rejecting friend request')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate rejecting friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avböj vänskapsförfrågan?',
      confirmationMessage: 'Vill du avböja vänskapsförfrågan från $senderName?',
      confirmActionText: 'Avböj',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: 'Vänskapsförfrågan från $senderName avböjd',
      errorMessage: 'Kunde inte avböja vänskapsförfrågan',
      metadata: {
        'request_id': requestId,
        'sender_name': senderName,
        'action': 'reject_single',
      },
    );
  }

  /// Cancel a sent friend request
  Future<void> cancelSentRequest(
    BuildContext context,
    String requestId,
    String recipientName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([requestId], 'canceling sent request')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate canceling sent request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avbryt vänskapsförfrågan?',
      confirmationMessage:
          'Vill du avbryta vänskapsförfrågan till $recipientName?',
      confirmActionText: 'Avbryt förfrågan',
      confirmationIcon: Icons.cancel,
      successMessage: 'Vänskapsförfrågan till $recipientName avbruten',
      errorMessage: 'Kunde inte avbryta vänskapsförfrågan',
      metadata: {
        'request_id': requestId,
        'recipient_name': recipientName,
        'action': 'cancel_sent',
      },
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Accept multiple friend requests with confirmation
  Future<void> acceptMultipleRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch accept
        showLoadingDialog(
            context, 'Accepterar ${requestIds.length} förfrågningar...');

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Acceptera alla valda?',
      confirmationMessage:
          'Vill du acceptera ${requestIds.length} vänskapsförfrågningar?',
      confirmActionText: 'Acceptera alla',
      confirmationIcon: Icons.check_circle,
      successMessage: '${requestIds.length} vänskapsförfrågningar accepterade',
      errorMessage: 'Kunde inte acceptera alla förfrågningar',
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'accept_multiple',
      },
    );
  }

  /// Reject multiple friend requests with confirmation
  Future<void> rejectMultipleRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch reject
        showLoadingDialog(
            context, 'Avböjer ${requestIds.length} förfrågningar...');

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avböj alla valda?',
      confirmationMessage:
          'Vill du avböja ${requestIds.length} vänskapsförfrågningar?',
      confirmActionText: 'Avböj alla',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '${requestIds.length} vänskapsförfrågningar avböjda',
      errorMessage: 'Kunde inte avböja alla förfrågningar',
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'reject_multiple',
      },
    );
  }

  /// Cancel multiple sent requests with confirmation
  Future<void> cancelMultipleSentRequests(
    BuildContext context,
    List<String> requestIds,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) || requestIds.isEmpty) {
      showErrorMessage(context, 'Inga förfrågningar valda');
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate batch cancel
        showLoadingDialog(
            context, 'Avbryter ${requestIds.length} förfrågningar...');

        await Future.delayed(const Duration(milliseconds: 1000));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Avbryt valda förfrågningar?',
      confirmationMessage:
          'Vill du avbryta ${requestIds.length} skickade förfrågningar?',
      confirmActionText: 'Avbryt alla',
      confirmationIcon: Icons.cancel,
      isDangerous: true,
      successMessage: '${requestIds.length} förfrågningar avbrutna',
      errorMessage: 'Kunde inte avbryta alla förfrågningar',
      metadata: {
        'request_count': requestIds.length,
        'request_ids': requestIds,
        'action': 'cancel_multiple',
      },
    );
  }

  // ===== FRIEND MANAGEMENT OPERATIONS =====

  /// Send friend request to user
  Future<void> sendFriendRequest(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'sending friend request')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate sending friend request
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: 'Vänskapsförfrågan skickad till $userName',
      errorMessage: 'Kunde inte skicka vänskapsförfrågan',
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'send_friend_request',
      },
    );
  }

  /// Remove friend with confirmation
  Future<void> removeFriend(
    BuildContext context,
    String friendId,
    String friendName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([friendId], 'removing friend')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate removing friend
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Ta bort vän?',
      confirmationMessage: 'Vill du ta bort $friendName från dina vänner?',
      confirmActionText: 'Ta bort',
      confirmationIcon: Icons.person_remove,
      isDangerous: true,
      successMessage: '$friendName har tagits bort från dina vänner',
      errorMessage: 'Kunde inte ta bort vän',
      metadata: {
        'friend_id': friendId,
        'friend_name': friendName,
        'action': 'remove_friend',
      },
    );
  }

  /// Block user with confirmation
  Future<void> blockUser(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'blocking user')) {
      return;
    }

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simulate blocking user
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      confirmationTitle: 'Blockera användare?',
      confirmationMessage: 'Vill du blockera $userName?\n\n'
          'Blockerade användare kan inte skicka vänskapsförfrågningar eller meddelanden till dig.',
      confirmActionText: 'Blockera',
      confirmationIcon: Icons.block,
      isDangerous: true,
      successMessage: '$userName har blockerats',
      errorMessage: 'Kunde inte blockera användare',
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'block_user',
      },
    );
  }

  /// Unblock user
  Future<void> unblockUser(
    BuildContext context,
    String userId,
    String userName,
    VoidCallback? onSuccess,
  ) async {
    if (!validateContext(context) ||
        !validateRequired([userId], 'unblocking user')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate unblocking user
        await Future.delayed(const Duration(milliseconds: 500));
        onSuccess?.call();
        return true;
      },
      successMessage: '$userName har avblockerats',
      errorMessage: 'Kunde inte avblockera användare',
      metadata: {
        'user_id': userId,
        'user_name': userName,
        'action': 'unblock_user',
      },
    );
  }

  // ===== HELPER OPERATIONS =====

  /// Refresh friend requests list
  Future<void> refreshFriendRequests(BuildContext context) async {
    if (!validateContext(context)) return;

    await executeAction(
      context: context,
      action: () async {
        // Simulate refresh
        await Future.delayed(const Duration(milliseconds: 800));
        return true;
      },
      successMessage: 'Vänskapsförfrågningar uppdaterade',
      errorMessage: 'Kunde inte uppdatera förfrågningar',
      metadata: {
        'action': 'refresh_friend_requests',
      },
    );
  }

  /// Search for users to send friend requests
  Future<void> searchUsers(
    BuildContext context,
    String query,
    Function(List<dynamic>) onResults,
  ) async {
    if (!validateContext(context) || query.trim().isEmpty) {
      showErrorMessage(context, 'Ange en sökterm');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // Simulate user search
        await Future.delayed(const Duration(milliseconds: 600));

        // Mock search results
        final results = [
          {'id': '1', 'name': 'Test User 1'},
          {'id': '2', 'name': 'Test User 2'},
        ];

        onResults(results);
        return true;
      },
      errorMessage: 'Kunde inte söka efter användare',
      metadata: {
        'search_query': query,
        'action': 'search_users',
      },
    );
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
  }
}

// ==================== FRIEND REQUEST CARD ====================

class _FriendRequestCard {
  static Widget buildIncomingCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged,
  ) {
    final userProfile = viewModel.getUserProfile(request.fromUserId);
    final displayName = userProfile?.displayName ??
        viewModel.getDisplayNameForUser(request.fromUserId);
    final avatarUrl = userProfile?.avatarUrl;
    final isOnline = userProfile?.isOnline ?? false;

    return Card(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => onSelectionChanged(!isSelected),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Column(
            children: [
              Row(
                children: [
                  // Selection checkbox
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => onSelectionChanged(value ?? false),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),

                  // User avatar with online indicator
                  Stack(
                    children: [
                      SocialComponents.avatar(
                        size: ImageSize.small,
                        imageUrl: avatarUrl,
                        displayName: displayName,
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppDimensions.spacingL),

                  // Request info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'vill bli vän',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (request.message?.isNotEmpty == true) ...[
                          const SizedBox(height: AppDimensions.spacingXs),
                          Container(
                            padding:
                                const EdgeInsets.all(AppDimensions.spacingS),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadius8),
                            ),
                            child: Text(
                              '"${request.message!}"',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          request.timeAgoText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Actions (not shown during bulk selection)
              if (!isSelected) ...[
                const SizedBox(height: AppDimensions.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: ActionButtons.outlinedButton(
                        context,
                        label: 'Avböj',
                        icon: Icons.close,
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _rejectRequest(context, request, viewModel),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingL),
                    Expanded(
                      child: StyledButton.primary(
                        text: 'Acceptera',
                        icon: const Icon(Icons.check),
                        onPressed: viewModel.isLoading
                            ? null
                            : () => _acceptRequest(context, request, viewModel),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildSentCard(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
    bool isSelected,
    Function(bool) onSelectionChanged,
  ) {
    final userProfile = viewModel.getUserProfile(request.toUserId);
    final displayName = userProfile?.displayName ??
        viewModel.getDisplayNameForUser(request.toUserId);
    final avatarUrl = userProfile?.avatarUrl;
    final isOnline = userProfile?.isOnline ?? false;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (request.status) {
      case FriendRequestStatus.pending:
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        statusText = 'Väntande svar';
        break;
      case FriendRequestStatus.accepted:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Accepterad';
        break;
      case FriendRequestStatus.rejected:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusText = 'Avböjd';
        break;
      case FriendRequestStatus.expired:
        statusColor = AppColors.neutralMedium;
        statusIcon = Icons.timer_off;
        statusText = 'Utgången';
        break;
      default:
        statusColor = AppColors.neutralMedium;
        statusIcon = Icons.help;
        statusText = 'Okänd status';
    }

    return Card(
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => onSelectionChanged(!isSelected),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          child: Row(
            children: [
              // Selection checkbox (only for pending requests)
              if (request.isPending)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged(value ?? false),
                )
              else
                const SizedBox(
                    width:
                        AppDimensions.spacingXxxl), // Placeholder for alignment

              const SizedBox(width: AppDimensions.spacingS),

              // User avatar with online indicator
              Stack(
                children: [
                  SocialComponents.avatar(
                    size: ImageSize.small,
                    imageUrl: avatarUrl,
                    displayName: displayName,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingL),

              // Request info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (request.message?.isNotEmpty == true)
                      Text(
                        request.message!,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Row(
                      children: [
                        Icon(statusIcon,
                            size: AppDimensions.iconSizeS, color: statusColor),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          request.timeAgoText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Cancel button for pending requests (not during selection)
              if (request.isPending && !isSelected)
                IconButton(
                  onPressed: () =>
                      _cancelSentRequest(context, request, viewModel),
                  icon: const Icon(Icons.cancel, color: AppColors.error),
                  tooltip: 'Avbryt förfrågan',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for actions
  static Future<void> _acceptRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.acceptFriendRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan accepterad! 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static Future<void> _rejectRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.rejectFriendRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vänskapsförfrågan avböjd'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  static Future<void> _cancelSentRequest(
    BuildContext context,
    FriendRequest request,
    FriendsViewModel viewModel,
  ) async {
    final success = await viewModel.cancelSentRequest(request.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Förfrågan avbruten'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }
}

// ==================== HEADER COMPONENTS ====================

class _FriendRequestsHeaderBuilder {
  static PreferredSizeWidget buildAppBar(
    BuildContext context,
    FriendsViewModel viewModel,
    TabController tabController,
    Function() onClearSelection,
    Set<String> selectedIncoming,
    Set<String> selectedSent,
    VoidCallback onBatchAccept,
    VoidCallback onBatchReject,
    VoidCallback onCancelSelected,
  ) {
    final totalRequests =
        viewModel.incomingRequests.length + viewModel.sentRequests.length;

    return AppBar(
      title: Text('Notiser ($totalRequests)'),
      bottom: TabBar(
        controller: tabController,
        onTap: (_) => onClearSelection(),
        tabs: [
          Tab(
            icon: Badge(
              isLabelVisible: viewModel.incomingRequests.isNotEmpty,
              label: Text('${viewModel.incomingRequests.length}'),
              child: const Icon(Icons.inbox),
            ),
            text: 'Inkommande',
          ),
          Tab(
            icon: Badge(
              isLabelVisible: viewModel.sentRequests.isNotEmpty,
              label: Text('${viewModel.sentRequests.length}'),
              child: const Icon(Icons.outbox),
            ),
            text: 'Skickade',
          ),
        ],
      ),
      actions: [
        // Batch actions for current tab
        if (tabController.index == 0 && selectedIncoming.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.checklist,
              color: AppColors.primaryBlue,
            ),
            onSelected: (value) {
              if (value == 'accept_all') {
                onBatchAccept();
              } else if (value == 'reject_all') {
                onBatchReject();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'accept_all',
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text('Acceptera valda (${selectedIncoming.length})'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reject_all',
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text('Avböj valda (${selectedIncoming.length})'),
                  ],
                ),
              ),
            ],
          ),
        if (tabController.index == 1 && selectedSent.isNotEmpty)
          IconButton(
            icon: const Icon(
              Icons.cancel,
              color: AppColors.error,
            ),
            onPressed: onCancelSelected,
            tooltip: 'Avbryt valda (${selectedSent.length})',
          ),
      ],
    );
  }

  static Widget buildErrorDisplay(
    BuildContext context,
    FriendsViewModel viewModel,
  ) {
    if (!viewModel.hasError) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      margin: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              viewModel.error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: viewModel.clearError,
            child: const Text('Stäng'),
          ),
        ],
      ),
    );
  }
}

// ==================== INCOMING REQUESTS TAB ====================

class _IncomingRequestsTabBuilder {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedIncoming,
    Function(String, bool) onSelectionChanged,
    VoidCallback onClearSelection,
  ) {
    if (viewModel.isLoading && viewModel.incomingRequests.isEmpty) {
      return StateWidget.loading(message: 'Laddar förfrågningar...');
    }

    if (viewModel.incomingRequests.isEmpty) {
      return StateWidget.empty(
        title: 'Inga vänskapsförfrågningar',
        subtitle: 'När någon skickar dig en vänskapsförfrågan visas den här.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
        onClearSelection();
      },
      child: Column(
        children: [
          // Selection header
          if (selectedIncoming.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedIncoming.length} förfrågningar valda',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: 'Rensa',
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.incomingRequests.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spacingS),
              itemBuilder: (context, index) {
                final request = viewModel.incomingRequests[index];
                final isSelected = selectedIncoming.contains(request.id);

                return _FriendRequestCard.buildIncomingCard(
                  context,
                  request,
                  viewModel,
                  isSelected,
                  (selected) => onSelectionChanged(request.id, selected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SENT REQUESTS TAB ====================

class _SentRequestsTabBuilder {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel,
    Set<String> selectedSent,
    Function(String, bool) onSelectionChanged,
    VoidCallback onClearSelection,
  ) {
    if (viewModel.isLoading && viewModel.sentRequests.isEmpty) {
      return StateWidget.loading(message: 'Laddar skickade förfrågningar...');
    }

    if (viewModel.sentRequests.isEmpty) {
      return StateWidget.empty(
        title: 'Inga skickade förfrågningar',
        subtitle: 'Förfrågningar du skickar till andra visas här.',
        icon: Icons.outbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.refresh();
        onClearSelection();
      },
      child: Column(
        children: [
          // Selection header
          if (selectedSent.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    '${selectedSent.length} förfrågningar valda',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  ActionButtons.secondaryButton(
                    context,
                    label: 'Rensa',
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ),

          // Requests list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              itemCount: viewModel.sentRequests.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spacingS),
              itemBuilder: (context, index) {
                final request = viewModel.sentRequests[index];
                final isSelected = selectedSent.contains(request.id);

                return _FriendRequestCard.buildSentCard(
                  context,
                  request,
                  viewModel,
                  isSelected,
                  (selected) => onSelectionChanged(request.id, selected),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
