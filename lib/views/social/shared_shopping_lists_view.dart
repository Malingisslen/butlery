/// View displaying collaborative shopping lists the user participates in.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_shopping_lists_viewmodel.dart';
import 'package:butlery/widgets/common/content_cards/shopping_list_card.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';

class SharedShoppingListsView extends StatelessWidget {
  const SharedShoppingListsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SharedShoppingListsViewModel(
        shoppingService: ServiceLocator.get(),
      ),
      child: Consumer<SharedShoppingListsViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.shoppingSharedLists),
            ),
            body: SafeArea(
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
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: viewModel.refreshData,
                          child: LoadingStateBuilder<List<UnifiedShoppingList>>(
                            isLoading: viewModel.isLoading,
                            error: viewModel.error,
                            data: viewModel.sharedLists,
                            onErrorRetry: viewModel.loadSharedLists,
                            emptyBuilder: (_) => ListView(
                              children: [
                                EmptyStates.buildEmptyState(
                                  context,
                                  variant:
                                      EmptyStateVariant.noSharedShoppingLists,
                                ),
                              ],
                            ),
                            builder: (context, lists) {
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.paddingM,
                                  vertical: AppDimensions.paddingS,
                                ),
                                itemCount: lists.length,
                                itemBuilder: (context, index) {
                                  final list = lists[index];
                                  return ShoppingListCard(
                                    key: ValueKey(list.id),
                                    shoppingList: list,
                                    style: ShoppingListCardStyle.compact,
                                    showSharingStatus: true,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      Routes.collaborativeShopping,
                                      arguments: list.id,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
