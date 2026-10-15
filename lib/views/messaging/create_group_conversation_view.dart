// lib/views/messaging/create_group_conversation_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/create_group_conversation_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// View for creating new group conversations: a name, the friends to invite
/// (at least two) and one saffron "Skapa konversation".
class CreateGroupConversationView extends StatefulWidget {
  const CreateGroupConversationView({super.key});

  @override
  State<CreateGroupConversationView> createState() =>
      _CreateGroupConversationViewState();
}

class _CreateGroupConversationViewState
    extends State<CreateGroupConversationView> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CreateGroupConversationViewModel>(
      create: (context) {
        final viewModel = CreateGroupConversationViewModel(
          friendsService: ServiceLocator.get(),
          chatGroupRepository: ServiceLocator.get(),
        );
        // Load friends immediately
        viewModel.loadFriends();
        return viewModel;
      },
      child: Consumer<CreateGroupConversationViewModel>(
        builder: (context, viewModel, child) {
          // BUT-727: guard accidental dismiss after typing a name or picking
          // members. Don't block while creating — that flow already returns
          // a value, so canPop should be true once create starts.
          final isDirty =
              !viewModel.isCreatingGroup &&
              (viewModel.groupName.trim().isNotEmpty ||
                  viewModel.hasSelectedMembers);
          return PopScope(
            canPop: !isDirty,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldLeave =
                  await CommonDialogActions.showUnsavedChangesConfirmation(
                    context: context,
                  );
              if (shouldLeave == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            // A form with its own bottom action (B-54): no tab bar.
            child: ButleryPage.undersida(
              title: context.l10n.messagingNewGroupChat,
              showTabBar: false,
              actions: [
                if (viewModel.hasSelectedMembers)
                  ButleryTextButton(
                    onPressed: viewModel.clearSelection,
                    label: context.l10n.commonClear,
                  ),
              ],
              body: _buildBody(context, viewModel),
              bottomNavigationBar: _buildBottomBar(context, viewModel),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(message: context.l10n.messagingLoadingFriends);
    }

    if (viewModel.error != null && viewModel.availableFriends.isEmpty) {
      return StateWidget.error(
        message: context.l10n.messagingCouldNotLoadFriends(viewModel.error!),
        onAction: () => viewModel.loadFriends(),
      );
    }

    if (viewModel.availableFriends.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.messagingNoFriendsAvailable,
        subtitle: context.l10n.messagingAddFriendsToCreateGroups,
      );
    }

    return SingleChildScrollView(
      padding: ButleryPageBody.margin(context, bottom: AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimensions.space16),
          _buildGroupNameSection(viewModel),
          const SizedBox(height: AppDimensions.space24),
          _buildParticipantsSection(viewModel),
          const SizedBox(height: AppDimensions.space16),
          _buildSearchSection(),
          const SizedBox(height: AppDimensions.space8),
          _buildFriendsList(viewModel),
        ],
      ),
    );
  }

  Widget _buildGroupNameSection(CreateGroupConversationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(context.l10n.messagingGroupName),
        const SizedBox(height: AppDimensions.space8),
        StyledInput.text(
          controller: _groupNameController,
          hint: context.l10n.messagingGroupNameHint,
          onChanged: (value) => viewModel.updateGroupName(value),
          errorText: viewModel.validationError,
        ),
      ],
    );
  }

  Widget _buildParticipantsSection(CreateGroupConversationViewModel viewModel) {
    if (!viewModel.hasSelectedMembers) {
      return Text(
        context.l10n.messagingSelectAtLeastTwoMembers,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          context.l10n.messagingSelectedMembers(viewModel.selectedMemberCount),
        ),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final member in viewModel.selectedMembers)
              _SelectedFriendChip(
                name: member.displayName,
                removeTooltip: context.l10n.a11yRemoveMember(
                  member.displayName,
                ),
                onRemove: () => viewModel.toggleMemberSelection(member.uid),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return ButlerySearchBox(
      controller: _searchController,
      hintText: context.l10n.messagingSearchFriends,
      onChanged: (value) => setState(() {}), // Rebuild to filter list
    );
  }

  Widget _buildFriendsList(CreateGroupConversationViewModel viewModel) {
    final searchQuery = _searchController.text;
    final displayFriends = searchQuery.isEmpty
        ? viewModel.availableFriends
        : viewModel.searchFriends(searchQuery);

    if (displayFriends.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.messagingNoFriendsFound,
        subtitle: context.l10n.messagingTryAnotherKeyword,
      );
    }

    return ButleryListSection(
      rows: [
        for (final friend in displayFriends)
          _buildFriendItem(viewModel, friend),
      ],
    );
  }

  Widget _buildFriendItem(
    CreateGroupConversationViewModel viewModel,
    UserProfile friend,
  ) {
    final isSelected = viewModel.isMemberSelected(friend.uid);
    // One node per friend: the row carries the name, the selected state and
    // the tap.
    return ButleryMediaRow(
      leading: AvatarCircle(
        imageUrl: friend.avatarUrl,
        displayName: friend.displayName,
      ),
      title: friend.displayName,
      selected: isSelected,
      onTap: () => viewModel.toggleMemberSelection(friend.uid),
      trailing: ExcludeSemantics(child: _CheckBox(checked: isSelected)),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) {
    return BottomActionContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: Text(
                viewModel.error!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // The view's one saffron action, "Skapa konversation" as drawn
          // (Skarmar v12 del 3 #nygruppchatt:602; Grafisk manual v6:219).
          HeroButton(
            key: const ValueKey('createGroupConversation.create'),
            label: context.l10n.messagingCreateConversation,
            onPressed: viewModel.canCreateGroup
                ? () => _handleCreateGroup(context, viewModel)
                : null,
            busy: viewModel.isCreatingGroup,
            expand: true,
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateGroup(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) async {
    // Capture context dependencies before async gap
    final navigator = Navigator.of(context);
    final successMsg = context.l10n.messagingGroupCreated;

    final conversationId = await viewModel.createGroupConversation();

    // Check mounted after async operation
    if (!mounted) return;

    if (conversationId != null) {
      SnackBarUtils.showSuccess(this.context, successMsg);

      // Navigate to chat view
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatViewFacade(
            conversationId: conversationId,
          ),
        ),
      );
    } else if (viewModel.error != null) {
      SnackBarUtils.showFailure(this.context, what: viewModel.error!);
    }
  }
}

/// A chosen participant: the name on an ink pill with a ×, as drawn.
class _SelectedFriendChip extends StatelessWidget {
  const _SelectedFriendChip({
    required this.name,
    required this.removeTooltip,
    required this.onRemove,
  });

  final String name;
  final String removeTooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      padding: const EdgeInsetsDirectional.only(start: AppDimensions.space16),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            child: Text(
              name,
              style: AppTextStyles.bodyBold.copyWith(color: cs.onPrimary),
            ),
          ),
          Tooltip(
            message: removeTooltip,
            child: PressFill(
              surface: PressSurface.ink,
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: AppDimensions.minTouchTarget,
                  height: AppDimensions.minTouchTarget,
                  child: Center(
                    child: ButleryIcon(
                      ButleryIcons.x,
                      size: AppDimensions.iconSizeS,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The square tick at the end of a friend row; the row says the state.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryOutlinedBox(
      width: 24,
      height: 24,
      color: checked ? cs.primary : null,
      borderColor: checked ? cs.primary : cs.outline,
      radius: AppDimensions.checkboxRadius,
      child: checked
          ? ButleryIcon(
              ButleryIcons.check,
              size: AppDimensions.iconSizeS,
              color: cs.onPrimary,
            )
          : null,
    );
  }
}
