// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../widgets/user/user_display_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/navigation_components.dart';
import '../../core/dialogs/dialog_factory.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../core/injection.dart';

/// Enkel vänprofilvy för att visa väninformation
class FriendProfileView extends StatelessWidget {
  final UserProfile friend;

  const FriendProfileView({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(friend.displayName),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.neutralLight,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          children: [
            // Avatar och grundläggande info
            Center(
              child: Column(
                children: [
                  UserDisplayWidgets.avatar(
                    imageUrl: friend.avatarUrl,
                    displayName: friend.displayName,
                    size: ImageSize.extraLarge,
                  ),
                  SizedBox(height: AppDimensions.spacingL),
                  Text(
                    friend.displayName,
                    style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (friend.bio?.isNotEmpty == true) ...[
                    SizedBox(height: AppDimensions.spacingS),
                    Text(
                      friend.bio!,
                      style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textMedium,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacingL),

            // Statistik kort
            Card(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik',
                      style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: AppDimensions.spacingL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          'Vänner',
                          '${friend.friendsCount}',
                          Icons.people,
                        ),
                        _buildStatItem(
                          context,
                          'Recept',
                          '${friend.publicRecipeCount}',
                          Icons.restaurant_menu,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppDimensions.spacingL),

            // Aktivitet kort
            Card(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktivitet',
                      style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: AppDimensions.spacingL),
                    ListTile(
                      leading: Icon(
                        Icons.access_time,
                        color: AppColors.primaryBlue,
                      ),
                      title: const Text('Senast aktiv'),
                      subtitle: Text(friend.lastActiveText),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: AppColors.primaryBlue,
                      ),
                      title: const Text('Medlem sedan'),
                      subtitle: Text(friend.memberSinceText),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.spacingL),

            // Action buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Meddelandefunktion kommer snart! 💌'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Skicka meddelande'),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingL),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showRecipeSelection(context),
                        icon: const Icon(Icons.share),
                        label: const Text('Dela recept'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingM),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRemoveFriendDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Ta bort vän'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UPPDATERAD: Använder NavigationComponents.showRecipeSelector()
  Future<void> _showRecipeSelection(BuildContext context) async {
    await NavigationComponents.showRecipeSelector(
      context,
      friend: friend,
    );
  }

  Future<void> _showRemoveFriendDialog(BuildContext context) async {
    final shouldRemove = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: friend.displayName,
      itemType: 'vän från din vänlista',
    );

    if (shouldRemove == true && context.mounted) {
      final viewModel = sl<FriendsViewModel>();
      final success = await viewModel.removeFriend(friend.uid);
      if (success && context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          '${friend.displayName} borttagen från vänlista',
        );
        Navigator.of(context).pop(); // Go back to friends list
      }
    }
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primaryBlue,
          size: AppDimensions.iconSizeXl,
        ),
        SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
        ),
      ],
    );
  }
}
