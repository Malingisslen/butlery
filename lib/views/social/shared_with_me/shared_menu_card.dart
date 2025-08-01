// lib/views/social/shared_with_me/shared_menu_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/viewmodels/shared_content_viewmodel.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// SharedMenuCard - Card for displaying shared menus
///
/// Displays shared menu information with action buttons.
class SharedMenuCard {
  static Widget build(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
  ) {
    final isRead = viewModel.isMenuRead(sharedMenu);
    final isImported = viewModel.isMenuImported(sharedMenu);

    return Card(
      elevation: isRead ? 1 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        onTap: () {
          if (!isRead) {
            viewModel.markMenuAsRead(sharedMenu);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: viewModel,
                child: MenuPreviewView(sharedMenu: sharedMenu),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: !isRead
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header med delningsinfo
              _buildHeader(context, viewModel, sharedMenu, isRead),
              const SizedBox(height: AppDimensions.spacingS),

              // Meny content
              _buildMenuContent(context, sharedMenu),

              // Message från delaren
              if (sharedMenu.shareMessage?.isNotEmpty == true) ...[
                const SizedBox(height: AppDimensions.spacingS),
                _buildShareMessage(context, sharedMenu.shareMessage!),
              ],

              const SizedBox(height: AppDimensions.spacingS),

              // Action buttons
              _buildActionButtons(
                context,
                viewModel,
                sharedMenu,
                isRead,
                isImported,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
    bool isRead,
  ) {
    return Row(
      children: [
        SocialComponents.avatar(
          size: ImageSize.small,
          displayName: sharedMenu.sharedByDisplayName,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delat av ${sharedMenu.sharedByDisplayName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                timeago.format(sharedMenu.sharedAt, locale: 'sv'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        // Dismiss knapp
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2),
            ),
          ),
          child: IconButton(
            onPressed: () => SharedContentActions.dismissMenu(
              context,
              viewModel,
              sharedMenu,
            ),
            icon: Icon(
              Icons.close,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Dölj från min lista',
            padding: const EdgeInsets.all(AppDimensions.spacingXs),
            constraints: const BoxConstraints(
              minWidth: AppDimensions.iconSizeAction + AppDimensions.spacingS,
              minHeight: AppDimensions.iconSizeAction + AppDimensions.spacingS,
            ),
          ),
        ),
        if (!isRead)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  static Widget _buildMenuContent(BuildContext context, SharedMenu sharedMenu) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(
            Icons.calendar_month,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedMenu.menuTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                sharedMenu.menuSummary,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    '${sharedMenu.totalRecipeCount} recept',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Icon(
                    Icons.category,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    '${sharedMenu.categories.length} kategorier',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildShareMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        '"$message"',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }

  static Widget _buildActionButtons(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedMenu sharedMenu,
    bool isRead,
    bool isImported,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (!isRead) {
                viewModel.markMenuAsRead(sharedMenu);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: viewModel,
                    child: MenuPreviewView(sharedMenu: sharedMenu),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Visa'),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: FilledButton.icon(
            onPressed: isImported || viewModel.isImporting
                ? null
                : () => SharedContentActions.importMenu(
                      context,
                      viewModel,
                      sharedMenu,
                    ),
            icon: isImported
                ? const Icon(Icons.check, size: 18)
                : viewModel.isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
            label: Text(
              isImported ? 'Importerat' : 'Importera',
            ),
          ),
        ),
      ],
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}