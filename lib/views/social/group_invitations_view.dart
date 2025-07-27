// lib/views/social/group_invitations_view.dart - 100% MVVM + AppTheme (KORRIGERAD)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/group_invitations_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';


class GroupInvitationsView extends StatelessWidget {
  const GroupInvitationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupInvitationsViewModel>(
      create: (context) => sl<GroupInvitationsViewModel>(),
      child: Consumer<GroupInvitationsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tillgängliga grupper'),
              // ✅ KORRIGERAT: Använd textTheme istället för icke-existerande styles
              titleTextStyle: Theme.of(context).textTheme.headlineSmall,
              backgroundColor: AppColors.backgroundBeige,
              foregroundColor: AppColors.textDark,
              elevation: AppDimensions.elevationLow,
              actions: [
                if (viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingL),
                    // ✅ KORRIGERAT: Använd smallLoadingIndicator som finns i AppTheme
                    child: SizedBox(
                      width: AppDimensions.iconSizeS,
                      height: AppDimensions.iconSizeS,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: viewModel.refresh,
                    tooltip: 'Uppdatera',
                  ),
              ],
            ),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, GroupInvitationsViewModel viewModel) {
    // Loading state
    if (viewModel.isLoading && viewModel.availableGroups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ KORRIGERAT: Använd mediumLoadingIndicator som finns
            CircularProgressIndicator(),
            SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Laddar grupper...',
              style: AppTextStyles.titleMedium,
            ),
          ],
        ),
      );
    }

    // Error state
    if (viewModel.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppDimensions.spacingXl),
              const Text(
                'Ett fel uppstod',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingM),
              // ✅ KORRIGERAT: Använd errorContainer som finns i AppTheme
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
              const SizedBox(height: AppDimensions.spacingXl),
              OutlinedButton.icon(
                onPressed: viewModel.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Försök igen'),
                // ✅ KORRIGERAT: Använd secondaryButtonStyle som finns
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (viewModel.availableGroups.isEmpty) {
      return StateWidget.empty(
        title: 'Inga grupper tillgängliga',
        subtitle: 'Det finns inga grupper att gå med i just nu. '
            'Fråga dina vänner om de har skapat några grupper!',
        icon: Icons.group_outlined,
        actionLabel: 'Uppdatera',
        onAction: viewModel.refresh,
      );
    }

    // Groups list
    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.availableGroups.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingXl),
        itemBuilder: (context, index) {
          final group = viewModel.availableGroups[index];
          return _buildGroupCard(context, group, viewModel);
        },
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    FriendCategory group,
    GroupInvitationsViewModel viewModel,
  ) {
    final members = viewModel.getMembersForGroup(group.id);
    final isJoining = viewModel.isJoiningGroup(group.id);

    return Card(
      elevation: AppDimensions.elevationLow,
      // ✅ KORRIGERAT: Använd largeRadius som finns definierat
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grupphuvud
            Row(
              children: [
                // Gruppikon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  child: Center(
                    child: Text(
                      group.emoji ?? '👥',
                      // ✅ KORRIGERAT: Använd befintlig textStyle och lägg till emoji-specifika egenskaper
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppDimensions.spacingM),

                // Gruppinfo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: AppTextStyles.titleMedium,
                      ),
                      // ✅ KORRIGERAT: Använd tinyGap som finns definierat
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        group.summary,
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppDimensions.spacingM),

                // Gå med-knapp
                FilledButton(
                  onPressed: isJoining
                      ? null
                      : () => _showJoinConfirmation(context, group, viewModel),
                  child: isJoining
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neutralLight),
                            ),
                            // ✅ KORRIGERAT: Använd tinyHorizontalGap som finns
                            const SizedBox(width: AppDimensions.spacingXs),
                            Text(
                              'Går med...',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.neutralLight,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Gå med',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.neutralLight,
                          ),
                        ),
                ),
              ],
            ),

            // Beskrivning
            if (group.description?.isNotEmpty == true) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                group.description!,
                style: AppTextStyles.bodyLarge,
              ),
            ],

            // Medlemmar
            if (members.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                'Medlemmar:',
                // ✅ KORRIGERAT: Använd formLabelStyle istället för icke-existerande labelStyle
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              _buildMembersList(context, members),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, List<dynamic> members) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...members.take(5).map((member) {
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingS),
              child: Column(
                children: [
                  SocialComponents.avatar(
                    displayName: member.displayName,
                    imageUrl: member.avatarUrl,
                    size: ImageSize.small,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  SizedBox(
                    width: 60,
                    child: Text(
                      member.displayName.split(' ').first,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (members.length > 5) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                // ✅ KORRIGERAT: Nu har vi context tillgängligt
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '+${members.length - 5}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showJoinConfirmation(
    BuildContext context,
    FriendCategory group,
    GroupInvitationsViewModel viewModel,
  ) async {
    final shouldJoin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // ✅ KORRIGERAT: Använd largeRadius istället för icke-existerande dialogShape
          title: Text(
          'Gå med i ${group.name}?',
          // ✅ KORRIGERAT: Använd sectionTitleStyle istället för icke-existerande dialogTitleStyle
          style: AppTextStyles.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodyLarge,
                children: [
                  const TextSpan(text: 'Vill du gå med i gruppen '),
                  TextSpan(
                    text: '"${group.name}"',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            if (group.description?.isNotEmpty == true) ...[
              const SizedBox(height: AppDimensions.spacingM),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  // ✅ KORRIGERAT: Använd Theme.of(context) istället för icke-existerande surfaceVariant
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Text(
                  group.description!,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            // ✅ KORRIGERAT: Använd secondaryButtonStyle istället för icke-existerande textButtonStyle
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
            ),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.cardWhite,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
            ),
            child: Text(
              'Gå med',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.neutralLight),
            ),
          ),
        ],
      ),
    );

    if (shouldJoin == true) {
      await viewModel.joinGroup(group.id);

      if (context.mounted && !viewModel.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Du är nu medlem i "${group.name}"! 🎉'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            // ✅ KORRIGERAT: Använd mediumRadius istället för icke-existerande snackBarShape
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM)),
          ),
        );
      }
    }
  }
}
