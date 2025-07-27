// lib/widgets/social/collaborative/components/collaborative_participants_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

/// Widgets for displaying collaborative participants
class CollaborativeParticipantsWidgets {
  /// Fetch real participants for collaborative content
  ///
  /// This method fetches actual participants from SharedRecipe/SharedMenu
  /// based on contentId and contentType
  static Widget participantsList({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    int maxVisible = 3,
    double avatarSize = 32,
  }) {
    return FutureBuilder<List<UserProfile>>(
      future: _getRealParticipants(context, contentId, contentType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Loading state - show skeleton avatars
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                2,
                (index) => Container(
                      width: avatarSize,
                      height: avatarSize,
                      margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    )),
          );
        }

        if (snapshot.hasError) {
          // Error state - show placeholder
          return Icon(
            Icons.people_outline,
            size: avatarSize,
            color: AppColors.textSecondary,
          );
        }

        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          // No participants - show placeholder
          return Icon(
            Icons.person_outline,
            size: avatarSize,
            color: AppColors.textSecondary,
          );
        }

        // Show real participants
        return avatarRow(
          participants: participants,
          maxVisible: maxVisible,
          totalCount: participants.length,
          size: avatarSize,
        );
      },
    );
  }

  /// Show participants as small avatars
  static Widget avatarRow({
    required List<UserProfile> participants,
    int maxVisible = 4,
    int? totalCount,
    double size = 32,
    EdgeInsets? spacing,
  }) {
    final visibleParticipants = participants.take(maxVisible).toList();
    final effectiveTotalCount = totalCount ?? participants.length;
    final remaining = effectiveTotalCount - maxVisible;
    final gap = spacing?.horizontal ?? AppDimensions.spacingXs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show visible participants - DELEGATE to UserDisplayWidgets
        for (int i = 0; i < visibleParticipants.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          UserDisplayWidgets.avatar(
            imageUrl: visibleParticipants[i].avatarUrl,
            displayName: visibleParticipants[i].displayName,
            size: _sizeToImageSize(size),
          ),
        ],

        // Show "+X" if there are more
        if (remaining > 0) ...[
          SizedBox(width: gap),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryBlue,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: size * 0.35,
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // PRIVATE HELPERS

  /// Fetch real participants from Firebase - ENHANCED VERSION
  static Future<List<UserProfile>> _getRealParticipants(
    BuildContext context,
    String contentId,
    String contentType,
  ) async {
    try {
      // Use SocialRecipeService for optimized participant loading
      final socialRecipeService = sl<SocialRecipeService>();

      debugPrint('🔍 Loading participants for $contentType: $contentId');

      List<UserProfile> participants = [];

      switch (contentType) {
        case 'recipe':
          participants =
              await socialRecipeService.getRecipeParticipants(contentId);
          break;

        case 'menu':
          participants =
              await socialRecipeService.getMenuParticipants(contentId);
          break;

        case 'shopping_list':
          participants =
              await socialRecipeService.getShoppingListParticipants(contentId);
          break;

        default:
          debugPrint('🔍 Unknown content type: $contentType');
          return [];
      }

      debugPrint(
          '🔍 Found ${participants.length} participants for $contentType $contentId');
      for (final participant in participants) {
        debugPrint(
            '🔍 Participant: ${participant.displayName} (${participant.uid})');
      }

      return participants;
    } catch (e) {
      debugPrint('❌ Error loading participants for $contentId: $e');
      return [];
    }
  }

  /// Convert size to ImageSize enum
  static ImageSize _sizeToImageSize(double size) {
    if (size <= 24) return ImageSize.small;
    if (size <= 32) return ImageSize.medium;
    if (size <= 48) return ImageSize.large;
    return ImageSize.extraLarge;
  }
}