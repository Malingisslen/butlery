// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../widgets/user/user_display_widgets.dart';
import '../../theme/app_theme.dart';
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
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.neutralLight,
      ),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
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
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: AppTheme.spacingMd),
                  Text(
                    friend.displayName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (friend.bio?.isNotEmpty == true) ...[
                    SizedBox(height: AppTheme.spacingSm),
                    Text(
                      friend.bio!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingLg),

            // Statistik kort
            Card(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: AppTheme.spacingMd),
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

            SizedBox(height: AppTheme.spacingMd),

            // Aktivitet kort
            Card(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aktivitet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: AppTheme.spacingMd),
                    ListTile(
                      leading: Icon(
                        Icons.access_time,
                        color: AppTheme.primaryColor,
                      ),
                      title: const Text('Senast aktiv'),
                      subtitle: Text(friend.lastActiveText),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                      ),
                      title: const Text('Medlem sedan'),
                      subtitle: Text(friend.memberSinceText),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.spacingLg),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meddelandefunktion kommer snart! 💌'),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Skicka meddelande'),
                  ),
                ),
                SizedBox(width: AppTheme.spacingMd),
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
          color: AppTheme.primaryColor,
          size: AppTheme.iconSizeDisplay,
        ),
        SizedBox(height: AppTheme.spacingXs),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
