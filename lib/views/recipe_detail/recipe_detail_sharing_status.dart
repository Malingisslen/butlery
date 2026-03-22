// lib/views/recipe_detail/recipe_detail_sharing_status.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Shows sharing status for a recipe the user owns.
/// Displays shared members/groups with per-item revoke buttons.
class RecipeDetailSharingStatus extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onSharingChanged;

  const RecipeDetailSharingStatus({
    super.key,
    required this.recipe,
    required this.onSharingChanged,
  });

  @override
  State<RecipeDetailSharingStatus> createState() =>
      _RecipeDetailSharingStatusState();
}

class _RecipeDetailSharingStatusState extends State<RecipeDetailSharingStatus> {
  late final String? _currentUserId;
  late final UnifiedFriendsService _friendsService;

  @override
  void initState() {
    super.initState();
    _currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    _friendsService = ServiceLocator.get<UnifiedFriendsService>();
  }

  Recipe get recipe => widget.recipe;
  VoidCallback get onSharingChanged => widget.onSharingChanged;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    // Only show for owner with sharing data
    if (recipe.createdBy != currentUserId) return const SizedBox.shrink();
    if (!recipe.isCollaborative && !recipe.isShared) {
      return const SizedBox.shrink();
    }

    final memberPermissions = recipe.socialData?.memberPermissions ?? {};
    final categoryIds = recipe.socialData?.categoryIds ?? [];

    // Filter out owner from member list
    final sharedMemberIds =
        memberPermissions.keys.where((id) => id != currentUserId).toList();

    if (sharedMemberIds.isEmpty && categoryIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.share_outlined,
                  size: AppDimensions.iconSizeM, color: cs.primary),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                context.l10n.recipeSharingStatus,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: cs.primary),
              ),
              const Spacer(),
              // Stop sharing with all
              TextButton.icon(
                onPressed: () => _confirmStopAll(context),
                icon: Icon(Icons.close,
                    size: AppDimensions.iconSizeS, color: cs.error),
                label: Text(
                  context.l10n.recipeSharingStopAll,
                  style: TextStyle(color: cs.error, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Shared friends
          if (sharedMemberIds.isNotEmpty) ...[
            Text(
              context.l10n.recipeSharingFriends,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            ...sharedMemberIds.map((userId) {
              final friend = _friendsService.friends
                  .where((f) => f.uid == userId)
                  .firstOrNull;
              final displayName = friend?.displayName ?? userId;
              return _ShareeRow(
                name: displayName,
                icon: Icons.person_outline,
                onRevoke: () =>
                    _confirmRevokeMember(context, userId, displayName),
              );
            }),
          ],

          // Shared groups
          if (categoryIds.isNotEmpty) ...[
            if (sharedMemberIds.isNotEmpty)
              const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n.recipeSharingGroups,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            ...categoryIds.map((groupId) {
              final group = _friendsService.categoriesList
                  .where((c) => c.id == groupId)
                  .firstOrNull;
              final displayName = group?.name ?? groupId;
              return _ShareeRow(
                name: displayName,
                icon: Icons.group_outlined,
                onRevoke: () =>
                    _confirmRevokeMember(context, groupId, displayName),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmStopAll(BuildContext context) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.recipeSharingStopAll,
      message: context.l10n.recipeSharingStopAllConfirm,
      confirmText: context.l10n.recipeSharingStopAll,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.unshareRecipe(recipe.id);

      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recipeSharingStopAllSuccess)),
        );
        onSharingChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonUnknownError)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonUnknownError)),
      );
    }
  }

  Future<void> _confirmRevokeMember(
    BuildContext context,
    String memberId,
    String displayName,
  ) async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.recipeSharingRevoke,
      message: context.l10n.recipeSharingRevokeConfirm(displayName),
      confirmText: context.l10n.recipeSharingRevoke,
      isDangerous: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final success = await recipeService.social
          .removeMember(recipeId: recipe.id, userId: memberId);

      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(context.l10n.recipeSharingRevokeSuccess(displayName))),
        );
        onSharingChanged();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commonUnknownError)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonUnknownError)),
      );
    }
  }
}

class _ShareeRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onRevoke;

  const _ShareeRow({
    required this.name,
    required this.icon,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconSizeS, color: cs.onSurfaceVariant),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton(
            onPressed: onRevoke,
            icon: Icon(Icons.close,
                size: AppDimensions.iconSizeS, color: cs.error),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: context.l10n.recipeSharingRevoke,
          ),
        ],
      ),
    );
  }
}
