// lib/views/social/create_shared_shopping_list_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/create_shared_list_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../services/friend_categories_service.dart';
import '../../widgets/common/utility_components.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';

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
          value: sl<FriendCategoriesService>(),
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
        icon: AppTheme.actionIcon(context, Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CreateSharedListViewModel viewModel) {
    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          _buildHeaderInfo(context),
          AppTheme.largeGap,

          // Lista detaljer
          _buildListDetails(context, viewModel),
          AppTheme.largeGap,

          // Vän selection
          _buildFriendSelection(context, viewModel),
          AppTheme.largeGap,

          // Info om vad som händer
          _buildInfoSection(context),

          // Error display
          if (viewModel.hasError) ...[
            AppTheme.mediumGap,
            AppTheme.errorContainer(context, viewModel.error!),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.infoBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.group,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Skapa delad inköpslista',
                style: AppTheme.cardTitleStyle.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          AppTheme.smallGap,
          Text(
            'Skapa en lista som du och dina vänner kan samarbeta kring i realtid.',
            style: AppTheme.subtitleStyle,
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
          'Lista detaljer',
          style: AppTheme.sectionTitleStyle,
        ),
        AppTheme.mediumGap,

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
        AppTheme.mediumGap,

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
        Text(
          'Välj vänner att dela med',
          style: AppTheme.sectionTitleStyle,
        ),
        AppTheme.mediumGap,
        Container(
          height: AppTheme.containerHeightLarge,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: AppTheme.mediumRadius,
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
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.successColor,
                size: AppTheme.iconSizeInfo,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                'Vad händer när du delar?',
                style: AppTheme.formLabelStyle.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppTheme.smallGap,
          Text(
            '• Dina valda vänner får en notifikation\n'
            '• De kan se listan, checka av artiklar och lägga till nya\n'
            '• Alla ändringar synkroniseras i realtid\n'
            '• Du kan hantera behörigheter senare',
            style: AppTheme.bodyStyle.copyWith(
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, CreateSharedListViewModel viewModel) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: AppTheme.dividerHeight,
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
                    style: AppTheme.formLabelStyle,
                  ),
                  if (viewModel.isTitleValid) ...[
                    AppTheme.tinyGap,
                    Text(
                      'Lista: "${viewModel.trimmedTitle}"',
                      style: AppTheme.captionStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            AppTheme.mediumHorizontalGap,

            SizedBox(
              width: AppTheme.buttonWidthMedium,
              child: FilledButton.icon(
                onPressed: viewModel.canCreate
                    ? () => _createSharedList(context, viewModel)
                    : null,
                icon: viewModel.isCreating
                    ? AppTheme.smallLoadingIndicator(color: AppTheme.neutralLight)
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
