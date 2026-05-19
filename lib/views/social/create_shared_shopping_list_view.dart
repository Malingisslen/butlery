// lib/views/social/create_shared_shopping_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

/// ✨ MIGRERAD CREATE SHARED SHOPPING LIST VY - Nu med UtilityComponents
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
          final isDirty = !viewModel.isCreating &&
              (viewModel.title.trim().isNotEmpty ||
                  viewModel.description.trim().isNotEmpty ||
                  viewModel.hasFriendsSelected);
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
            child: Scaffold(
              appBar: _buildAppBar(context, viewModel),
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
                    child: _buildBody(context, viewModel),
                  ),
                ),
              ),
              bottomNavigationBar: _buildBottomBar(context, viewModel),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return AppBar(
      title: Text(
          '${context.l10n.commonShare} ${context.l10n.shoppingList.toLowerCase()}'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        // Route through Navigator.maybePop so the same PopScope guard applies
        // to the explicit close button as to the system-back gesture.
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CreateSharedListViewModel viewModel) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _buildHeaderInfo(context),
            const SizedBox(height: AppDimensions.spacingXl),

            // Lista detaljer
            _buildListDetails(context, viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

            // Friend selection
            _buildFriendSelection(context, viewModel),
            const SizedBox(height: AppDimensions.spacingXl),

            // Info about what happens
            _buildInfoSection(context),

            // Error display
            if (viewModel.hasError) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: AppDimensions.opacityMediumLight)),
                ),
                child: Text(
                  viewModel.error!,
                  style: AppTextStyles.bodyMediumError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.group,
                color: Theme.of(context).colorScheme.primary,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                context.l10n.shoppingCreateSharedList,
                style: AppTextStyles.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.shoppingCreateSharedListDescription,
            style: AppTextStyles.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildListDetails(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shoppingListDetails,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Titel med real-time validation
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: context.l10n.shoppingSharedListTitle,
            hintText: context.l10n.shoppingSharedListTitleHint,
            prefixIcon: const Icon(Icons.title),
            errorText: viewModel.titleError,
          ),
          onChanged: viewModel.updateTitle,
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Beskrivning med validation
        StyledInput(
          controller: _descriptionController,
          label: context.l10n.shoppingDescriptionOptional,
          hint: context.l10n.shoppingDescriptionHint,
          maxLines: 3,
          minLines: 1,
          onChanged: viewModel.updateDescription,
        ),
      ],
    );
  }

  Widget _buildFriendSelection(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shoppingSelectFriendsToShare,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        BorderedContainer(
          height: 200,
          child: UtilityComponents.friendCategoryManager(
            selectedFriendIds: viewModel.selectedFriendIds,
            onSelectionChanged: viewModel.updateSelectedFriends,
            title: '',
            subtitle: '',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: context.butleryColors.success
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color: context.butleryColors.success
                .withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: context.butleryColors.success,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                context.l10n.shoppingWhatHappensWhenSharing,
                style: AppTextStyles.titleBold.copyWith(
                  color: context.butleryColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.shoppingShareInfoBullets,
            style: AppTextStyles.bodyLarge.copyWith(
              color: context.butleryColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return BottomActionContainer(
      child: Row(
        children: [
          // Selection summary from ViewModel
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.selectedFriendsText,
                  style: AppTextStyles.labelLarge,
                ),
                if (viewModel.isTitleValid) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    'Lista: "${viewModel.trimmedTitle}"',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacingM),

          SizedBox(
            width: 120,
            child: ActionButtons.primaryButton(
              context,
              label: viewModel.createButtonText,
              icon: viewModel.isCreating ? null : Icons.group_add,
              onPressed: viewModel.canCreate
                  ? () => _createSharedList(context, viewModel)
                  : null,
              isLoading: viewModel.isCreating,
              isExpanded: true,
            ),
          ),
        ],
      ),
    );
  }

  // Pure MVVM: Business logic delegeras till ViewModel
  Future<void> _createSharedList(
      BuildContext context, CreateSharedListViewModel viewModel) async {
    // Store context reference before async operation
    final navigator = Navigator.of(context);

    final listId = await viewModel.createSharedList();

    // Use mounted check without using context across async gaps
    if (mounted && listId != null) {
      // Success - return listId using stored navigator
      navigator.pop(listId);
    }
    // Error handling is managed by ViewModel and shown in UI automatically
  }
}
