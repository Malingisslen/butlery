// lib/views/social/add_members_to_group_view.dart - KOMPLETT med StateWidget migration

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

class AddMembersToGroupView extends StatefulWidget {
  final String groupId;

  const AddMembersToGroupView({
    super.key,
    required this.groupId,
  });

  @override
  State<AddMembersToGroupView> createState() => _AddMembersToGroupViewState();
}

class _AddMembersToGroupViewState extends State<AddMembersToGroupView> {
  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔍 DEBUG: AddMembersToGroupView.initState() - groupId: ${widget.groupId}');
  }

  @override
  void dispose() {
    debugPrint('🔍 DEBUG: AddMembersToGroupView.dispose()');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔍 DEBUG: AddMembersToGroupView.build() kallad för groupId: ${widget.groupId}');

    return ChangeNotifierProvider<AddMembersToGroupViewModel>(
      create: (context) {
        debugPrint(
            '🔍 DEBUG: Creating AddMembersToGroupViewModel från View med groupId: ${widget.groupId}');
        debugPrint(
            '🔍 DEBUG: ServiceLocator tillgänglig: ${sl.isRegistered<AddMembersToGroupViewModel>()}');

        try {
          final viewModel =
              sl<AddMembersToGroupViewModel>(param1: widget.groupId);
          debugPrint(
              '🔍 DEBUG: AddMembersToGroupViewModel skapad framgångsrikt: ${viewModel.runtimeType}');
          debugPrint('🔍 DEBUG: ViewModel groupId: ${viewModel.groupId}');
          return viewModel;
        } catch (e) {
          debugPrint(
              '🔍 DEBUG: KRITISKT FEL vid skapande av AddMembersToGroupViewModel: $e');
          debugPrint('🔍 DEBUG: Stack trace: ${StackTrace.current}');
          rethrow;
        }
      },
      child: Consumer<AddMembersToGroupViewModel>(
        builder: (context, viewModel, child) {
          debugPrint(
              '🔍 DEBUG: Consumer building med viewModel: ${viewModel.runtimeType}');
          debugPrint(
              '🔍 DEBUG: ViewModel state - isLoading: ${viewModel.isLoading}, hasError: ${viewModel.hasError}');
          debugPrint(
              '🔍 DEBUG: Available friends count: ${viewModel.availableFriendsCount}');
          debugPrint(
              '🔍 DEBUG: Selected friends count: ${viewModel.selectedCount}');

          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
            bottomNavigationBar: _buildBottomBar(viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AddMembersToGroupViewModel viewModel) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lägg till medlemmar',
            style: AppTextStyles.headlineSmall,
          ),
          if (viewModel.group != null)
            Text(
              viewModel.group!.name,
              style: AppTextStyles.titleMedium,
            ),
        ],
      ),
      backgroundColor: AppColors.backgroundBeige,
      foregroundColor: AppColors.textDark,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.hasSelectedFriends)
          TextButton(
            onPressed: () {
              debugPrint('🔍 DEBUG: "Välj alla" knapp tryckt');
              viewModel.selectAllVisible();
            },
            child: Text(
              'Välj alla',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        if (viewModel.hasSelectedFriends)
          TextButton(
            onPressed: () {
              debugPrint('🔍 DEBUG: "Rensa" knapp tryckt');
              viewModel.clearAllSelections();
            },
            child: Text(
              'Rensa',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, AddMembersToGroupViewModel viewModel) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(
          message: 'Laddar vänner...'); // ✅ MIGRATION: StateWidget
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.showEmptyState) {
      // ✅ MIGRATION: StateWidget istället för EmptyState
      return StateWidget.empty(
        title: 'Inga vänner tillgängliga',
        subtitle: 'Alla dina vänner är redan medlemmar i denna grupp, '
            'eller så har du redan skickat inbjudningar till dem.',
        icon: Icons.people_outline,
        actionLabel: 'Uppdatera',
        onAction: () {
          debugPrint('🔍 DEBUG: Empty state refresh tryckt');
          viewModel.refresh();
        },
      );
    }

    return Column(
      children: [
        // Search bar
        _buildSearchBar(viewModel),

        // Selection controls
        if (viewModel.filteredFriends.isNotEmpty)
          _buildSelectionControls(viewModel),

        // Friends list
        Expanded(
          child: _buildFriendsList(viewModel),
        ),
      ],
    );
  }

  Widget _buildSearchBar(AddMembersToGroupViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: TextField(
        onChanged: (value) {
          debugPrint('🔍 DEBUG: Search query ändrad: "$value"');
          viewModel.updateSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'Sök vänner...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: viewModel.hasSearchQuery
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    debugPrint('🔍 DEBUG: Search clear tryckt');
                    viewModel.clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionControls(AddMembersToGroupViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL).copyWith(top: 0),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textMedium,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              viewModel.hasSelectedFriends
                  ? '${viewModel.selectedCount} av ${viewModel.filteredFriends.length} vald(a)'
                  : 'Välj vänner att bjuda in till gruppen',
              style: AppTextStyles.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(AddMembersToGroupViewModel viewModel) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: viewModel.filteredFriends.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingM),
      itemBuilder: (context, index) {
        final friend = viewModel.filteredFriends[index];
        return _buildFriendTile(friend, viewModel);
      },
    );
  }

  Widget _buildFriendTile(
      UserProfile friend, AddMembersToGroupViewModel viewModel) {
    final isSelected = viewModel.isFriendSelected(friend.uid);
    final hasInvitation = viewModel.hasInvitationStatus(friend.uid);
    final invitationStatus = viewModel.getInvitationStatusForUser(friend.uid);

    return Card(
      elevation: AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
      child: ListTile(
        leading: SocialComponents.avatar(
          user: friend,
          size: ImageSize.medium,
        ),
        title: Text(
          friend.displayName,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: friend.bio?.isNotEmpty == true
            ? Text(
                friend.bio!,
                style: AppTextStyles.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: _buildFriendTileTrailing(
            friend, viewModel, isSelected, hasInvitation, invitationStatus),
        onTap: () {
          debugPrint(
              '🔍 DEBUG: Friend tile tapped - ${friend.displayName} (${friend.uid})');
          viewModel.toggleFriendSelection(friend.uid);
        },
      ),
    );
  }

  Widget _buildFriendTileTrailing(
    UserProfile friend,
    AddMembersToGroupViewModel viewModel,
    bool isSelected,
    bool hasInvitation,
    String? invitationStatus,
  ) {
    if (hasInvitation) {
      // Visa inbjudningsstatus
      Color statusColor;
      IconData statusIcon;
      String statusText;

      switch (invitationStatus) {
        case 'sent':
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle;
          statusText = 'Skickad';
          break;
        case 'failed':
          statusColor = AppColors.error;
          statusIcon = Icons.error;
          statusText = 'Misslyckades';
          break;
        default:
          statusColor = AppColors.warning;
          statusIcon = Icons.schedule;
          statusText = 'Väntar';
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(color: statusColor),
          ),
        ],
      );
    }

    // Visa selection checkbox
    return Checkbox(
      value: isSelected,
      onChanged: (value) {
        debugPrint(
            '🔍 DEBUG: Checkbox changed för ${friend.displayName} - new value: $value');
        viewModel.toggleFriendSelection(friend.uid);
      },
      activeColor: AppColors.primaryBlue,
    );
  }

  Widget _buildBottomBar(AddMembersToGroupViewModel viewModel) {
    if (!viewModel.hasSelectedFriends) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: const BoxDecoration(
        color: AppColors.backgroundBeige,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewModel.invitationError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Text(
                        viewModel.invitationError!,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],
            FilledButton(
              onPressed: viewModel.isSendingInvitations
                  ? null
                  : () async {
                      debugPrint(
                          '🔍 DEBUG: ===== SKICKA INBJUDNINGAR KNAPP TRYCKT =====');
                      debugPrint(
                          '🔍 DEBUG: Selected friends: ${viewModel.selectedFriendIds.toList()}');
                      debugPrint(
                          '🔍 DEBUG: ViewModel kan skicka: ${viewModel.canSendInvitations}');
                      debugPrint(
                          '🔍 DEBUG: ViewModel isSending: ${viewModel.isSendingInvitations}');

                      final success = await viewModel.sendInvitations();

                      debugPrint(
                          '🔍 DEBUG: sendInvitations() result: $success');

                      if (mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${viewModel.selectedCount} inbjudningar skickade! 📨',
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.cardWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
              ),
              child: viewModel.isSendingInvitations
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.neutralLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Text(
                          'Skickar...',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.neutralLight,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Skicka ${viewModel.selectedCount} inbjudningar',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.neutralLight,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AddMembersToGroupViewModel viewModel) {
    return StateWidget.error(
      message: viewModel.error ?? 'Okänt fel',
      onAction: () {
        debugPrint('🔍 DEBUG: Error state retry tryckt');
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }
}
