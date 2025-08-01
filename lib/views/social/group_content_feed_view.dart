// lib/views/social/group_content_feed_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

import 'package:butlery/widgets/common/state_widget.dart';

// Import focused components
import 'package:butlery/views/social/group_content_feed/group_content_app_bar.dart';
import 'package:butlery/views/social/group_content_feed/group_content_search_bar.dart';
import 'package:butlery/views/social/group_content_feed/group_content_tab_bar.dart';
import 'package:butlery/views/social/group_content_feed/group_content_lists.dart';
import 'package:butlery/views/social/group_content_feed/group_activity_timeline.dart';

/// Group Content Feed View - Browse content shared to specific groups
/// 
/// This view allows users to:
/// - Browse recipes, menus, and shopping lists shared to a specific group
/// - See group activity timeline
/// - Filter and search group content
/// - View group content statistics
/// - Access group shared content management
class GroupContentFeedView extends StatelessWidget {
  final FriendCategory group;

  const GroupContentFeedView({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupContentViewModel>(
      create: (context) => ServiceLocator.get<GroupContentViewModel>()..initialize(group),
      child: _GroupContentFeedViewContent(group: group),
    );
  }
}

class _GroupContentFeedViewContent extends StatefulWidget {
  final FriendCategory group;

  const _GroupContentFeedViewContent({
    required this.group,
  });

  @override
  State<_GroupContentFeedViewContent> createState() =>
      _GroupContentFeedViewContentState();
}

class _GroupContentFeedViewContentState
    extends State<_GroupContentFeedViewContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Recipes, Menus, Shopping Lists, Activity

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<GroupContentViewModel>();

      // Sync tab controller with ViewModel
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          viewModel.setTabIndex(_tabController.index);
        }
      });
    });

    // Configure Swedish for timeago
    timeago.setLocaleMessages('sv', timeago.SvMessages());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<GroupContentViewModel>(
        builder: (context, viewModel, _) {
          return CustomScrollView(
            slivers: [
              GroupContentAppBar.build(context, viewModel, widget.group),
              GroupContentSearchBar.build(context, viewModel, _searchController),
              GroupContentTabBar.build(context, viewModel, _tabController),
              _buildContent(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, GroupContentViewModel viewModel) {
    if (viewModel.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: AppDimensions.iconSizeL,
                height: AppDimensions.iconSizeL,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: AppDimensions.spacingXl),
              Text(
                'Laddar gruppinnehåll...',
                style: AppTextStyles.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.hasError) {
      return SliverFillRemaining(
        child: StateWidget.error(
          message: viewModel.error!,
          onAction: viewModel.loadGroupContent,
        ),
      );
    }

    if (!viewModel.hasGroupContent) {
      return SliverFillRemaining(
        child: StateWidget.empty(
          title: 'Inget delat innehåll',
          subtitle:
              'Inga recept, menyer eller inköpslistor har delats till gruppen "${widget.group.name}" än.',
          icon: Icons.group_outlined,
          actionLabel: 'Dela innehåll',
          onAction: () => _showShareContentDialog(context),
        ),
      );
    }

    if (!viewModel.hasFilteredContent && viewModel.searchQuery.isNotEmpty) {
      return SliverFillRemaining(
        child: StateWidget.noSearchResults(
          actionLabel: 'Rensa sökning',
          onAction: () {
            _searchController.clear();
            viewModel.clearSearch();
          },
        ),
      );
    }

    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          GroupContentLists.buildRecipesList(context, viewModel, _searchController),
          GroupContentLists.buildMenusList(context, viewModel, _searchController),
          GroupContentLists.buildShoppingListsList(context, viewModel, _searchController),
          GroupActivityTimeline.build(context, viewModel),
        ],
      ),
    );
  }

  void _showShareContentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Dela innehåll med gruppen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Dela recept'),
              subtitle: const Text('Välj ett recept att dela'),
              onTap: () {
                Navigator.pop(context);
                _shareRecipe(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Dela meny'),
              subtitle: const Text('Dela en veckomeny'),
              onTap: () {
                Navigator.pop(context);
                _shareMenu(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Dela inköpslista'),
              subtitle: const Text('Dela en inköpslista'),
              onTap: () {
                Navigator.pop(context);
                _shareShoppingList(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Skicka meddelande'),
              subtitle: const Text('Starta en konversation'),
              onTap: () {
                Navigator.pop(context);
                _startConversation(context);
              },
            ),
            
            const SizedBox(height: AppDimensions.spacingM),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _shareRecipe(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/mina-recept',
      arguments: {
        'selectMode': true,
        'groupId': widget.group.id,
      },
    );
  }
  
  void _shareMenu(BuildContext context) {
    Navigator.pushNamed(context, '/veckomeny');
  }
  
  void _shareShoppingList(BuildContext context) {
    Navigator.pushNamed(context, '/inkopslista');
  }
  
  void _startConversation(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/messages',
      arguments: {'groupId': widget.group.id},
    );
  }
}