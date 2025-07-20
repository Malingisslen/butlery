// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../widgets/user/user_display_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/navigation_components.dart';

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
                  UserDisplayWidgets.editableAvatar(
                    imageUrl: friend.avatarUrl,
                    displayName: friend.displayName,
                    onEditTap: () {
                      // För vänprofiler - visa bara ett meddelande
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kan inte redigera vänners profiler'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
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
