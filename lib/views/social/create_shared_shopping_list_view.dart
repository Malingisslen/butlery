// lib/views/social/create_shared_shopping_list_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/list/person_check_row.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

class CreateSharedShoppingListView extends StatefulWidget {
  const CreateSharedShoppingListView({super.key});

  @override
  State<CreateSharedShoppingListView> createState() =>
      _CreateSharedShoppingListViewState();
}

class _CreateSharedShoppingListViewState
    extends State<CreateSharedShoppingListView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final FriendsViewModel _friendsViewModel;

  @override
  void initState() {
    super.initState();
    _friendsViewModel = ServiceLocator.get<FriendsViewModel>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        final viewModel = context.read<CreateSharedListViewModel>();
        viewModel.initialize(
          menu: args['menu'],
          defaultTitle: args['defaultTitle'],
        );

        // Synka controllers med ViewModel
        _titleController.text = viewModel.title;
        _descriptionController.text = viewModel.description;
      }
    });
  }

  @override
  void dispose() {
    _friendsViewModel.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CreateSharedListViewModel(),
        ),
        ChangeNotifierProvider.value(
          value: _friendsViewModel,
        ),
        Provider.value(
          value: ServiceLocator.get<UnifiedFriendsService>(),
        ),
      ],
      child: Consumer<CreateSharedListViewModel>(
        builder: (context, viewModel, child) {
          // BUT-727: guard accidental dismiss after typing a title/description
          // or selecting friends. Skip the prompt while the create call is in
          // flight — we don't want to interrupt that.
          final isDirty = !viewModel.isCreating && viewModel.hasUserInput;
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
            child: ButleryPage.undersida(
              title: context.l10n.shoppingNewSharedListTitle,
              showTabBar: false,
              body: _buildBody(context, viewModel),
              bottomNavigationBar: _buildBottomBar(context, viewModel),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CreateSharedListViewModel viewModel) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StyledInput(
              label: context.l10n.shoppingSharedListNameLabel,
              controller: _titleController,
              textInputAction: TextInputAction.next,
              hint: context.l10n.shoppingSharedListTitleHint,
              errorText: viewModel.titleError,
              onChanged: viewModel.updateTitle,
            ),
            const SizedBox(height: AppDimensions.space24),
            StyledInput(
              label: context.l10n.shoppingDescriptionOptional,
              controller: _descriptionController,
              minLines: 1,
              maxLines: 3,
              hint: context.l10n.shoppingDescriptionHint,
              onChanged: viewModel.updateDescription,
            ),
            const SizedBox(height: AppDimensions.space24),
            _buildFriendSelection(context, viewModel),
            const SizedBox(height: AppDimensions.space24),
            _buildPermission(context, viewModel),
            if (viewModel.hasError) ...[
              const SizedBox(height: AppDimensions.space24),
              InlineError(what: viewModel.error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSelection(
    BuildContext context,
    CreateSharedListViewModel viewModel,
  ) {
    final friends = context.watch<FriendsViewModel>().friends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(context.l10n.shoppingShareWithHeading),
        const SizedBox(height: AppDimensions.space4),
        if (friends.isEmpty)
          Text(
            context.l10n.shoppingNoFriendsToShareWith,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final friend in friends)
            PersonCheckRow(
              key: ValueKey('createSharedList.friend.${friend.uid}'),
              name: friend.displayName,
              avatarUrl: friend.avatarUrl,
              checked: viewModel.selectedFriendIds.contains(friend.uid),
              onChanged: (_) => viewModel.toggleFriend(friend.uid),
            ),
      ],
    );
  }

  Widget _buildPermission(
    BuildContext context,
    CreateSharedListViewModel viewModel,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.shoppingPermissionHeading),
        const SizedBox(height: AppDimensions.space8),
        UnderlineTabs<bool>(
          values: const [true, false],
          labelOf: (canEdit) => canEdit
              ? l10n.shoppingPermissionCanEdit
              : l10n.shoppingPermissionReadOnlyTab,
          selected: viewModel.membersCanEdit,
          onChanged: viewModel.setMembersCanEdit,
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          viewModel.membersCanEdit
              ? l10n.shoppingPermissionCanEditHelp
              : l10n.shoppingPermissionViewOnlyHelp,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CreateSharedListViewModel viewModel,
  ) {
    return BottomActionContainer(
      // The view's one primary action (Skarmar v12 del 3 'Ny delad
      // inköpslista', "Skapa och dela").
      child: FormButton(
        key: const ValueKey('createSharedList.create'),
        label: viewModel.createButtonText,
        onPressed: viewModel.canCreate
            ? () => _createSharedList(context, viewModel)
            : null,
        busy: viewModel.isCreating,
        expand: true,
      ),
    );
  }

  // Pure MVVM: Business logic delegeras till ViewModel
  Future<void> _createSharedList(
    BuildContext context,
    CreateSharedListViewModel viewModel,
  ) async {
    // Store context reference before async operation
    final navigator = Navigator.of(context);

    final listId = await viewModel.createSharedList();

    // Use mounted check without using context across async gaps
    if (mounted && context.mounted && listId != null) {
      // The list exists even when some invitations did not go out (BUT-2089).
      final notInvited = viewModel.notInvitedNames;
      if (notInvited.isNotEmpty) {
        SnackBarUtils.showWarning(
          context,
          context.l10n.listInviteConvertedSomeNotInvited(notInvited.join(', ')),
        );
      }
      // Success - return listId using stored navigator
      navigator.pop(listId);
    }
    // Error handling is managed by ViewModel and shown in UI automatically
  }
}
