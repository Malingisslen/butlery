// lib/widgets/social/collaborative/components/collaborative_participants_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Widgets for displaying collaborative participants
class CollaborativeParticipantsWidgets {
  /// Fetch real participants for collaborative content
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
              (index) => Padding(
                padding: EdgeInsetsDirectional.only(start: index > 0 ? 4 : 0),
                child: ButleryDisc(
                  size: avatarSize,
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          // Error state - show placeholder
          return ButleryIcon(
            ButleryIcons.users,
            size: avatarSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }

        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          // No participants - show placeholder
          return ButleryIcon(
            ButleryIcons.user,
            size: avatarSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final gap = spacing?.horizontal ?? AppDimensions.space4;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleParticipants.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          AvatarCircle(
            imageUrl: visibleParticipants[i].avatarUrl,
            displayName: visibleParticipants[i].displayName,
            size: size <= AvatarCircleSize.inline.pixels
                ? AvatarCircleSize.inline
                : AvatarCircleSize.row,
          ),
        ],

        // Show "+X" if there are more
        if (remaining > 0) ...[
          SizedBox(width: gap),
          Builder(
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return ButleryDisc(
                size: size,
                color: cs.surface,
                borderColor: cs.onSurface,
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: AppTextStyles.bodyLargeBold.copyWith(
                      fontSize: size * 0.35,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              );
            },
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
      final socialRecipeService = ServiceLocator.get<SocialRecipeService>();

      List<UserProfile> participants = [];

      switch (contentType) {
        case 'recipe':
          participants = await socialRecipeService.getRecipeParticipants(
            contentId,
          );
          break;

        case 'menu':
          participants = await socialRecipeService.getMenuParticipants(
            contentId,
          );
          break;

        case 'shopping_list':
          participants = await socialRecipeService.getShoppingListParticipants(
            contentId,
          );
          break;

        default:
          return [];
      }

      return participants;
    } catch (_) {
      return [];
    }
  }
}
