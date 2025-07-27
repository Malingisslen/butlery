// lib/views/social/create_shared_shopping_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';

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

  @override
  void initState() {
    super.initState();

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
        ChangeNotifierProvider(
          create: (_) => sl<FriendsViewModel>(),
        ),
        ChangeNotifierProvider.value(
          value: sl<UnifiedFriendsService>(),
        ),
      ],
      child: Consumer<CreateSharedListViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
            bottomNavigationBar: _buildBottomBar(context, viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return AppBar(
      title: const Text('Dela inköpslista'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CreateSharedListViewModel viewModel) {
    return SingleChildScrollView(
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

          // Vän selection
          _buildFriendSelection(context, viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Info om vad som händer
          _buildInfoSection(context),

          // Error display
          if (viewModel.hasError) ...[
            const SizedBox(height: AppDimensions.spacingXl),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                viewModel.error!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.group,
                color: AppColors.primaryBlue,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                'Skapa delad inköpslista',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Skapa en lista som du och dina vänner kan samarbeta kring i realtid.',
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
        const Text(
          'Lista detaljer',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Titel med real-time validation
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titel på delad lista',
            hintText: 'T.ex. "Middag hos Anna", "Veckans handling"',
            prefixIcon: const Icon(Icons.title),
            errorText: viewModel.titleError,
          ),
          onChanged: viewModel.updateTitle,
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Beskrivning med validation
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Beskrivning (valfri)',
            hintText: 'T.ex. "Handla till middagsmys på fredag"',
            prefixIcon: const Icon(Icons.description),
            errorText: viewModel.descriptionError,
          ),
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
        const Text(
          'Välj vänner att dela med',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          // ✅ MIGRERAD: FriendCategoryManager → UtilityComponents.friendCategoryManager
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
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.success,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Text(
                'Vad händer när du delar?',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            '• Dina valda vänner får en notifikation\n'
            '• De kan se listan, checka av artiklar och lägga till nya\n'
            '• Alla ändringar synkroniseras i realtid\n'
            '• Du kan hantera behörigheter senare',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppDimensions.borderWidthThin,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Selection summary från ViewModel
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
              child: FilledButton.icon(
                onPressed: viewModel.canCreate
                    ? () => _createSharedList(context, viewModel)
                    : null,
                icon: viewModel.isCreating
                    ? const SizedBox(
                        width: AppDimensions.iconSizeS,
                        height: AppDimensions.iconSizeS,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.neutralLight),
                        ),
                      )
                    : const Icon(Icons.group_add),
                label: Text(viewModel.createButtonText),
              ),
            ),
          ],
        ),
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
    // Error handling sköts av ViewModel och visas i UI automatiskt
  }
}
