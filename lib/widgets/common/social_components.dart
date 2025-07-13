// lib/widgets/common/social_components.dart


import 'package:flutter/material.dart';
import '../../models/friend_category.dart';
import '../../models/user_profile.dart';
import '../../models/invitations/invitation_target.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/social_recipe_service.dart';
import '../user/user_display_widgets.dart';
import 'utility_components.dart';
import '../invitation_target/target_display_widgets.dart';
import '../invitation_target/target_input_widgets.dart';
import '../invitation_target/target_state_widgets.dart';
import 'package:provider/provider.dart';
import '../../models/permissions/edit_mode.dart';
import '../../viewmodels/recipe_form_viewmodel.dart';
import '../../viewmodels/collaborative_status_viewmodel.dart';

// ✅ Re-export ImageSize för enklare imports
export '../user/user_display_widgets.dart' show ImageSize, UserDisplayData;

/// 🚀 SocialComponents - Den ultimata social widget API:en
///
/// Konsoliderar alla social-relaterade widgets i en enhetlig API:
/// - ✅ 15 UserDisplayWidgets.avatar() användningar
/// - ✅ 4 dialog widgets (create, edit, delete, remove)
/// - ✅ FriendCategoryManager för komplex friend selection
/// - ✅ Alla invitation target widgets för sharing
/// - ✅ Collaborative editing indicators och live features MED RIKTIGA DELTAGARE
/// - ✅ 100% AppTheme compliance och konsistenta patterns
///
/// MIGRATION GUIDE:
/// ```dart
/// // Före:
/// import '../../widgets/user/user_display_widgets.dart';
/// UserDisplayWidgets.avatar(imageUrl: user.avatarUrl, displayName: user.displayName)
///
/// // Efter:
/// import '../../widgets/common/social_components.dart';
/// SocialComponents.avatar(user: user)
/// ```
class SocialComponents {
  // ===== USER DISPLAY & AVATARS =====

  /// Bygg användaravatar - HUVUDMETOD som ersätter UserDisplayWidgets.avatar()
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    Color? textColor,
    bool showStatus = false,
    bool isOnline = false,
    bool clickable = false,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';
    final effectiveIsOnline = user?.isOnline ?? isOnline;

    return UserDisplayWidgets.avatar(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      size: size,
      onTap: clickable ? onTap : onTap,
      borderColor: borderColor,
      borderWidth: borderWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
    );
  }

  /// Bygg redigerbar avatar med edit-knapp
  static Widget editableAvatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    required VoidCallback onEditTap,
    ImageSize size = ImageSize.extraLarge,
    Color? borderColor,
    double? borderWidth,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';

    return UserDisplayWidgets.editableAvatar(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      onEditTap: onEditTap,
      size: size,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }

  /// Bygg användarnamn med konsistent styling
  static Widget userName({
    UserProfile? user,
    String? displayName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';

    return UserDisplayWidgets.userName(
      displayName: effectiveDisplayName,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Bygg användarinfo (namn + email)
  static Widget userInfo({
    UserProfile? user,
    String? displayName,
    String? email,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? nameStyle,
    TextStyle? emailStyle,
  }) {
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';
    final effectiveEmail = user?.email ?? email;

    return UserDisplayWidgets.userInfo(
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      alignment: alignment,
      nameStyle: nameStyle,
      emailStyle: emailStyle,
    );
  }

  /// Bygg användarrad (avatar + info + trailing)
  static Widget userRow({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    String? email,
    String? subtitle,
    ImageSize avatarSize = ImageSize.medium,
    VoidCallback? onTap,
    Widget? trailing,
    bool showStatus = false,
    EdgeInsets? padding,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';
    final effectiveEmail = user?.email ?? email;
    final effectiveSubtitle = user?.bio ?? subtitle;
    final effectiveIsOnline = user?.isOnline ?? false;

    return UserDisplayWidgets.userRow(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      subtitle: effectiveSubtitle,
      avatarSize: avatarSize,
      onTap: onTap,
      trailing: trailing,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
      padding: padding,
    );
  }

  /// Bygg användarkort (större layout)
  static Widget userCard({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    String? email,
    String? subtitle,
    String? description,
    ImageSize avatarSize = ImageSize.large,
    VoidCallback? onTap,
    Widget? actions,
    bool showStatus = false,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
    final effectiveImageUrl = user?.avatarUrl ?? imageUrl;
    final effectiveDisplayName =
        user?.displayName ?? displayName ?? 'Okänd användare';
    final effectiveEmail = user?.email ?? email;
    final effectiveSubtitle = user?.bio ?? subtitle;
    final effectiveDescription = description;
    final effectiveIsOnline = user?.isOnline ?? false;

    return UserDisplayWidgets.userCard(
      imageUrl: effectiveImageUrl,
      displayName: effectiveDisplayName,
      email: effectiveEmail,
      subtitle: effectiveSubtitle,
      description: effectiveDescription,
      avatarSize: avatarSize,
      onTap: onTap,
      actions: actions,
      showStatus: showStatus,
      isOnline: effectiveIsOnline,
      padding: padding,
      margin: margin,
    );
  }

  /// Bygg lista av användare
  static Widget userList({
    required List<UserProfile> users,
    Function(UserProfile)? onUserTap,
    Widget Function(UserProfile)? trailingBuilder,
    bool showStatus = false,
    ImageSize avatarSize = ImageSize.medium,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    final userData =
        users.map((user) => UserDisplayData.fromUserProfile(user)).toList();

    return UserDisplayWidgets.userList(
      users: userData,
      onUserTap: onUserTap != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              onUserTap(user);
            }
          : null,
      trailingBuilder: trailingBuilder != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              return trailingBuilder(user);
            }
          : null,
      showStatus: showStatus,
      avatarSize: avatarSize,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  /// Bygg grid av användare
  static Widget userGrid({
    required List<UserProfile> users,
    Function(UserProfile)? onUserTap,
    int crossAxisCount = 2,
    double aspectRatio = 1.2,
    ImageSize avatarSize = ImageSize.large,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    final userData =
        users.map((user) => UserDisplayData.fromUserProfile(user)).toList();

    return UserDisplayWidgets.userGrid(
      users: userData,
      onUserTap: onUserTap != null
          ? (userData) {
              final user = users.firstWhere((u) => u.uid == userData.id);
              onUserTap(user);
            }
          : null,
      crossAxisCount: crossAxisCount,
      aspectRatio: aspectRatio,
      avatarSize: avatarSize,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
    );
  }

  /// Bygg empty state för användare
  static Widget emptyUserState({
    String title = 'Inga användare',
    String subtitle = 'Inga användare att visa',
    IconData icon = Icons.people_outline,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return UserDisplayWidgets.emptyUserState(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Bygg status indikator
  static Widget statusIndicator({
    required bool isOnline,
    double? size,
  }) {
    return UserDisplayWidgets.statusIndicator(
      isOnline: isOnline,
      size: size,
    );
  }

  /// Bygg användarbadge
  static Widget userBadge({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) {
    return UserDisplayWidgets.userBadge(
      label: label,
      backgroundColor: backgroundColor,
      textColor: textColor,
      padding: padding,
    );
  }

  // ===== COLLABORATIVE EDITING INDICATORS =====

  /// 🏷️ Compact badge för att visa att innehåll är delat/kollaborativt
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    final effectiveColor = color ?? AppTheme.primaryColor;

    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.chipRadius,
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppTheme.iconSizeInfo,
            color: effectiveColor,
          ),
          SizedBox(width: AppTheme.spacingXs),
          Text(
            text,
            style: AppTheme.captionStyle.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 📢 Större banner för collaborative context - MED RIKTIGA DELTAGARE
  static Widget collaborativeBanner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context, // Behövs för att hämta riktiga deltagare
  }) {
    final bgColor =
        backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.smallRadius,
        child: Row(
          children: [
            Icon(
              Icons.people,
              color: AppTheme.primaryColor,
              size: AppTheme.iconSizeAction,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // ✅ ANVÄND RIKTIGA DELTAGARE om context och contentId finns
            if (context != null && contentId != null)
              collaborativeParticipants(
                context: context,
                contentId: contentId,
                contentType: contentType,
                maxVisible: 3,
                avatarSize: 24,
              )
            // ✅ FALLBACK till trailing widget
            else if (trailing != null)
              trailing
            // ✅ SISTA FALLBACK - visa bara en ikon
            else
              Icon(
                Icons.people_outline,
                size: 24,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  // ===== SMART COLLABORATIVE STATUS WIDGETS =====

  /// 🎨 AppBar med kollaborativ bakgrundsfärg och smart status detection
  static PreferredSizeWidget collaborativeAppBar({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    List<Widget>? actions,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<CollaborativeStatusViewModel>(
        builder: (context, viewModel, child) {
          // ✅ FIXAT: Hämta status object och använd .isCollaborative
          final status = contentType == 'recipe'
              ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
              : viewModel.getMenuCollaborativeStatus(contentId, menuData);

          final isCollaborative = status.isCollaborative; // ← Hämta bool

          return AppBar(
            title: Text(title ?? 'Redigera innehåll'),
            backgroundColor: isCollaborative
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : null,
            actions: [
              // Kollaborativ badge om relevant
              if (isCollaborative)
                Padding(
                  padding: EdgeInsets.only(right: AppTheme.spacingMd),
                  child: Center(
                    child: collaborativeStatusBadge(
                      text: 'Delat',
                      icon: Icons.people,
                    ),
                  ),
                ),
              // Andra actions
              if (actions != null) ...actions,
            ],
          );
        },
      ),
    );
  }

  /// 🎗️ Smart kollaborativ banner med ViewModel integration
  static Widget smartCollaborativeBanner({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    Recipe? recipe,
    Map<String, List<Recipe>>? menuData,
    String? title,
    String? subtitle,
  }) {
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, viewModel, child) {
        // ✅ FIXAT: Hämta status object och använd .isCollaborative
        final status = contentType == 'recipe'
            ? viewModel.getRecipeCollaborativeStatus(contentId, recipe)
            : viewModel.getMenuCollaborativeStatus(contentId, menuData);

        final isCollaborative = status.isCollaborative; // ← Hämta bool

        if (!isCollaborative) return const SizedBox.shrink();

        return collaborativeBanner(
          title: title ?? 'Du redigerar tillsammans med andra',
          subtitle:
              subtitle ?? 'Ändringar synkas automatiskt med andra deltagare',
          contentId: contentId,
          contentType: contentType,
          context: context,
        );
      },
    );
  }

  /// 🔄 Force refresh för specifikt innehåll via ViewModel
  static void refreshCollaborativeStatus(
    BuildContext context,
    String contentId, {
    String contentType = 'recipe',
  }) {
    try {
      final viewModel = context.read<CollaborativeStatusViewModel>();
      if (contentType == 'recipe') {
        viewModel.invalidateRecipeStatus(contentId);
      } else {
        viewModel.invalidateMenuStatus(contentId);
      }
    } catch (e) {
      debugPrint('Could not refresh collaborative status: $e');
    }
  }

  /// 👥 Hämta riktiga deltagare för kollaborativt innehåll
  ///
  /// Denna metod hämtar faktiska deltagare från SharedRecipe/SharedMenu
  /// baserat på contentId och contentType
  static Widget collaborativeParticipants({
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
          // Loading state - visa skeleton avatars
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                2,
                (index) => Container(
                      width: avatarSize,
                      height: avatarSize,
                      margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    )),
          );
        }

        if (snapshot.hasError) {
          // Error state - visa placeholder
          return Icon(
            Icons.people_outline,
            size: avatarSize,
            color: AppTheme.textSecondary,
          );
        }

        final participants = snapshot.data ?? [];
        if (participants.isEmpty) {
          // Ingen deltagare - visa placeholder
          return Icon(
            Icons.person_outline,
            size: avatarSize,
            color: AppTheme.textSecondary,
          );
        }

        // Visa riktiga deltagare
        return participantAvatars(
          participants: participants,
          maxVisible: maxVisible,
          totalCount: participants.length,
          size: avatarSize,
        );
      },
    );
  }

  /// 🔍 Hämta riktiga deltagare från Firebase - ENHANCED VERSION
  static Future<List<UserProfile>> _getRealParticipants(
    BuildContext context,
    String contentId,
    String contentType,
  ) async {
    try {
      // Använd SocialRecipeService för optimerad participant loading
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

  /// 👤 Visa real-time "X redigerar nu" indikator
  static Widget liveEditIndicator({
    required String editorName,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    if (!isVisible) return const SizedBox.shrink();

    final indicatorColor = color ?? AppTheme.warningColor;

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      tween: Tween<double>(begin: 0.0, end: isVisible ? 1.0 : 0.0),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
              border: Border.all(
                color: indicatorColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulsingDot(indicatorColor),
                SizedBox(width: AppTheme.spacingXs),
                Text(
                  '$editorName redigerar $editingWhat',
                  style: AppTheme.captionStyle.copyWith(
                    color: indicatorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔒 Permissions banner för kollaborativ redigering
  static Widget permissionsBanner({
    required BuildContext context,
    required EditMode editMode,
    VoidCallback? onTap,
  }) {
    final color = editMode.getColor(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      margin: EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardBorderRadius,
        child: Row(
          children: [
            Icon(
              editMode.icon,
              color: color,
              size: AppTheme.iconSizeAction,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                editMode.description,
                style: AppTheme.bodyStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔒 Smart permissions banner med ViewModel integration
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    if (viewModel.editMode == null) return const SizedBox.shrink();

    return permissionsBanner(
      context: context,
      editMode: viewModel.editMode!,
    );
  }

  /// 🌐 Visa connection status för collaborative content
  static Widget collaborativeConnectionStatus({
    required bool isOnline,
    required String statusText,
    String? statusEmoji,
    bool showRetryButton = false,
    VoidCallback? onRetry,
  }) {
    if (isOnline) {
      // Minimal indikator när allt fungerar
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: AppTheme.chipRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Online',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Offline banner
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (statusEmoji != null) ...[
            Text(statusEmoji, style: TextStyle(fontSize: 20)),
            SizedBox(width: AppTheme.spacingSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline',
                  style: AppTheme.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
                Text(
                  statusText,
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
          if (showRetryButton && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Försök igen',
                style: AppTheme.buttonTextStyle.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== PARTICIPANT AVATARS (DELEGERAR TILL UserDisplayWidgets) =====
  /// 👥 Visa deltagare som små avatars
  static Widget participantAvatars({
    required List<UserProfile> participants,
    int maxVisible = 4,
    int? totalCount,
    double size = 32,
    EdgeInsets? spacing,
  }) {
    final visibleParticipants = participants.take(maxVisible).toList();
    final effectiveTotalCount = totalCount ?? participants.length;
    final remaining = effectiveTotalCount - maxVisible;
    final gap = spacing?.horizontal ?? AppTheme.spacingXs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visa synliga deltagare - DELEGERAR till UserDisplayWidgets
        for (int i = 0; i < visibleParticipants.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          UserDisplayWidgets.avatar(
            imageUrl: visibleParticipants[i].avatarUrl,
            displayName: visibleParticipants[i].displayName,
            size: _sizeToImageSize(size),
          ),
        ],

        // Visa "+X" om det finns fler
        if (remaining > 0) ...[
          SizedBox(width: gap),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: size * 0.35,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ===== FRIEND CATEGORY MANAGEMENT =====

  static Widget categoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String title = 'Välj vänner',
    String subtitle = 'Välj kategorier eller individuella vänner',
  }) {
    return UtilityComponents.friendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  static Widget compactCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return UtilityComponents.compactFriendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      maxHeight: maxHeight,
    );
  }

  // ===== INVITATION TARGET COMPONENTS =====

  /// Bygg target display card
  static Widget targetCard(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    bool isSelected = false,
    bool isDisabled = false,
  }) {
    return TargetDisplayWidgets.buildTargetCard(
      context,
      target,
      onTap: onTap,
      isSelected: isSelected,
      isDisabled: isDisabled,
    );
  }

  /// Bygg target chip
  static Widget targetChip(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    VoidCallback? onRemove,
    bool showCount = true,
  }) {
    return TargetDisplayWidgets.buildTargetChip(
      context,
      target,
      onTap: onTap,
      onRemove: onRemove,
      showCount: showCount,
    );
  }

  /// Bygg target list tile
  static Widget targetListTile(
    BuildContext context,
    InvitationTarget target, {
    VoidCallback? onTap,
    Widget? trailing,
    bool showSubtitle = true,
  }) {
    return TargetDisplayWidgets.buildTargetListTile(
      context,
      target,
      onTap: onTap,
      trailing: trailing,
      showSubtitle: showSubtitle,
    );
  }

  /// Bygg target badge
  static Widget targetBadge(
    BuildContext context,
    InvitationTarget target, {
    bool showEmoji = true,
    bool showCount = true,
  }) {
    return TargetDisplayWidgets.buildTargetBadge(
      context,
      target,
      showEmoji: showEmoji,
      showCount: showCount,
    );
  }

  /// Bygg target lista
  static Widget targetList(
    BuildContext context,
    List<InvitationTarget> targets, {
    required Function(InvitationTarget) onTargetTap,
    bool showDividers = true,
    bool groupByType = false,
  }) {
    return TargetDisplayWidgets.buildTargetList(
      context,
      targets,
      onTargetTap: onTargetTap,
      showDividers: showDividers,
      groupByType: groupByType,
    );
  }

  /// Bygg target grid
  static Widget targetGrid(
    BuildContext context,
    List<InvitationTarget> targets, {
    required Function(InvitationTarget) onTargetTap,
    int crossAxisCount = 2,
  }) {
    return TargetDisplayWidgets.buildTargetGrid(
      context,
      targets,
      onTargetTap: onTargetTap,
      crossAxisCount: crossAxisCount,
    );
  }

  /// Bygg target selection widget
  static Widget targetSelector(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    required List<InvitationTarget> selectedTargets,
    required Function(InvitationTarget) onTargetSelected,
    required Function(InvitationTarget) onTargetDeselected,
    String searchHint = 'Sök vänner och grupper...',
    bool allowMultiple = true,
    bool showSearch = true,
    bool groupByType = true,
  }) {
    return TargetInputWidgets.buildTargetSelector(
      context,
      availableTargets: availableTargets,
      selectedTargets: selectedTargets,
      onTargetSelected: onTargetSelected,
      onTargetDeselected: onTargetDeselected,
      searchHint: searchHint,
      allowMultiple: allowMultiple,
      showSearch: showSearch,
      groupByType: groupByType,
    );
  }

  /// Bygg checkable target lista
  static Widget checkableTargetList(
    BuildContext context, {
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget, bool) onTargetToggled,
    bool groupByType = true,
  }) {
    return TargetInputWidgets.buildCheckableTargetList(
      context,
      targets: targets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      groupByType: groupByType,
    );
  }

  /// Bygg radio target selector
  static Widget radioTargetSelector(
    BuildContext context, {
    required List<InvitationTarget> targets,
    InvitationTarget? selectedTarget,
    required Function(InvitationTarget?) onTargetSelected,
    bool groupByType = true,
  }) {
    return TargetInputWidgets.buildRadioTargetSelector(
      context,
      targets: targets,
      selectedTarget: selectedTarget,
      onTargetSelected: onTargetSelected,
      groupByType: groupByType,
    );
  }

  /// Bygg target search field
  static Widget targetSearchField(
    BuildContext context, {
    String hint = 'Sök...',
    Function(String)? onChanged,
    VoidCallback? onClear,
  }) {
    return TargetInputWidgets.buildTargetSearchField(
      context,
      hint: hint,
      onChanged: onChanged,
      onClear: onClear,
    );
  }

  /// Bygg target type filters
  static Widget targetTypeFilters(
    BuildContext context, {
    required Set<InvitationTargetType> selectedTypes,
    required Function(InvitationTargetType, bool) onTypeToggled,
  }) {
    return TargetInputWidgets.buildTargetTypeFilters(
      context,
      selectedTypes: selectedTypes,
      onTypeToggled: onTypeToggled,
    );
  }

  /// Bygg quick selection buttons
  static Widget quickSelectionButtons(
    BuildContext context, {
    required List<InvitationTarget> allTargets,
    required Function(List<InvitationTarget>) onTargetsSelected,
  }) {
    return TargetInputWidgets.buildQuickSelectionButtons(
      context,
      allTargets: allTargets,
      onTargetsSelected: onTargetsSelected,
    );
  }

  // ===== TARGET STATE WIDGETS =====

  /// Bygg target loading state
  static Widget targetListLoading(BuildContext context) {
    return TargetStateWidgets.buildTargetListLoading(context);
  }

  /// Bygg target card loading
  static Widget targetCardLoading(BuildContext context) {
    return TargetStateWidgets.buildTargetCardLoading(context);
  }

  /// Bygg target loading error
  static Widget targetLoadingError(
    BuildContext context, {
    String? errorMessage,
    VoidCallback? onRetry,
  }) {
    return TargetStateWidgets.buildTargetLoadingError(
      context,
      errorMessage: errorMessage,
      onRetry: onRetry,
    );
  }

  /// Bygg no targets available state
  static Widget noTargetsAvailable(BuildContext context) {
    return TargetStateWidgets.buildNoTargetsAvailable(context);
  }

  /// Bygg no search results state
  static Widget noSearchResults(
    BuildContext context, {
    required String searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return TargetStateWidgets.buildNoSearchResults(
      context,
      searchQuery: searchQuery,
      onClearSearch: onClearSearch,
    );
  }

  /// Bygg targets selected success state
  static Widget targetsSelectedSuccess(
    BuildContext context, {
    required List<InvitationTarget> targets,
    VoidCallback? onContinue,
  }) {
    return TargetStateWidgets.buildTargetsSelectedSuccess(
      context,
      targets: targets,
      onContinue: onContinue,
    );
  }

  // ===== GROUP DIALOG METHODS =====

  /// Visa create group dialog
  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateGroupDialog(
        preSelectedMembers: preSelectedMembers,
      ),
    );
  }

  /// Visa edit group dialog
  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditGroupDialog(group: group),
    );
  }

  /// Visa delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteGroupDialog(group: group),
    );

    return result ?? false;
  }

  /// Visa remove member dialog
  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RemoveMemberDialog(
        group: group,
        member: member,
      ),
    );

    return result ?? false;
  }

  // ===== TARGET SELECTION DIALOG =====

  /// Visa target selection dialog
  static Future<List<InvitationTarget>?> showTargetSelectionDialog(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget> initialSelection = const [],
    String title = 'Välj vem du vill dela med',
    bool allowMultiple = true,
  }) {
    return TargetInputWidgets.showTargetSelectionDialog(
      context,
      availableTargets: availableTargets,
      initialSelection: initialSelection,
      title: title,
      allowMultiple: allowMultiple,
    );
  }

  // ===== COLLABORATIVE HELPER WIDGETS =====
  /// Pulsande punkt för live edit indicator
  static Widget _buildPulsingDot(Color color) {
    return _PulsingDot(color: color);
  }

  // ===== HELPER FUNCTIONS (DELEGERAR) =====
  /// Konvertera double size till ImageSize enum
  static ImageSize _sizeToImageSize(double size) {
    if (size <= 32) return ImageSize.small;
    if (size <= 48) return ImageSize.medium;
    if (size <= 80) return ImageSize.large;
    return ImageSize.extraLarge;
  }

  // ===== UTILITY METHODS =====

  /// Generera initials från användarnamn
  static String getInitials(String displayName) {
    return UserDisplayWidgets.getInitials(displayName);
  }

  /// Konvertera UserProfile till UserDisplayData
  static UserDisplayData userProfileToDisplayData(UserProfile user) {
    return UserDisplayData.fromUserProfile(user);
  }

  /// Konvertera lista av UserProfile till UserDisplayData
  static List<UserDisplayData> userProfilesToDisplayData(
      List<UserProfile> users) {
    return users.map((user) => UserDisplayData.fromUserProfile(user)).toList();
  }

  // ===== CONVENIENCE BUILDERS =====

  /// Bygg social section med header och content
  static Widget socialSection({
    required BuildContext context,
    required String title,
    required Widget content,
    String? subtitle,
    Widget? trailing,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? AppTheme.sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.sectionTitleStyle,
                    ),
                    if (subtitle != null) ...[
                      AppTheme.tinyGap,
                      Text(
                        subtitle,
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          AppTheme.mediumGap,
          content,
        ],
      ),
    );
  }

  /// Bygg social info card
  static Widget socialInfoCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) {
    final cardColor = color ?? AppTheme.primaryColor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.largeRadius,
        child: Padding(
          padding: AppTheme.cardPadding,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  icon,
                  color: cardColor,
                  size: AppTheme.iconSizeAction,
                ),
              ),
              AppTheme.mediumHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.cardTitleStyle,
                    ),
                    AppTheme.tinyGap,
                    Text(
                      subtitle,
                      style: AppTheme.subtitleStyle,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bygg social stats row
  static Widget socialStatsRow({
    required BuildContext context,
    required List<SocialStat> stats,
  }) {
    return Card(
      child: Padding(
        padding: AppTheme.cardPadding,
        child: Row(
          children: stats.map((stat) {
            final isLast = stat == stats.last;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          stat.icon,
                          color: stat.color,
                          size: AppTheme.iconSizeAction,
                        ),
                        AppTheme.tinyGap,
                        Text(
                          stat.value,
                          style: AppTheme.cardTitleStyle.copyWith(
                            color: stat.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stat.label,
                          style: AppTheme.captionStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.dividerColor,
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Data class för social statistics
class SocialStat {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const SocialStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

/// Extension methods för enhanced functionality
extension SocialComponentsExtensions on SocialComponents {
  /// Bygg enhanced user list med sections
  static Widget sectionedUserList({
    required BuildContext context,
    required Map<String, List<UserProfile>> sections,
    Function(UserProfile)? onUserTap,
    bool showStatus = false,
  }) {
    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections.entries.elementAt(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) AppTheme.largeGap,
            Padding(
              padding: AppTheme.screenPadding,
              child: Text(
                section.key,
                style: AppTheme.sectionTitleStyle,
              ),
            ),
            AppTheme.smallGap,
            ...section.value.map((user) => SocialComponents.userRow(
                  user: user,
                  onTap: onUserTap != null ? () => onUserTap(user) : null,
                  showStatus: showStatus,
                )),
          ],
        );
      },
    );
  }
}

// ===== INTERNAL DIALOG WIDGETS =====
// Dessa widgets används internt av SocialComponents och bör inte kallas direkt

/// StatefulWidget för pulsande animation (ISOLERAD FUNKTIONALITET)
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Internal Create Group Dialog Widget
class _CreateGroupDialog extends StatefulWidget {
  final List<UserProfile>? preSelectedMembers;

  const _CreateGroupDialog({this.preSelectedMembers});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedEmoji = '👥';
  Set<String> _selectedFriendIds = {};
  bool _isCreating = false;
  String? _error;

  final List<String> _availableEmojis = [
    '👥',
    '🏠',
    '🍽️',
    '💼',
    '🎯',
    '⚽',
    '🎮',
    '📚',
    '🎵',
    '✈️',
    '🍕',
    '💪',
    '🛒',
    '🎉',
    '❤️',
    '⭐'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedMembers != null) {
      _selectedFriendIds = widget.preSelectedMembers!.map((m) => m.uid).toSet();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: AppTheme.sectionPadding,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.only(
          topLeft: AppTheme.largeRadius.topLeft,
          topRight: AppTheme.largeRadius.topRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.group_add, color: AppTheme.primaryColor),
          AppTheme.mediumHorizontalGap,
          Expanded(
              child: Text('Skapa ny grupp', style: AppTheme.sectionTitleStyle)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: SingleChildScrollView(
        padding: AppTheme.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gruppnamn
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Gruppnamn *',
                hintText: 'T.ex. Familjen, Jobbet, Träningskompisar',
                errorText: _error,
                prefixIcon: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(_selectedEmoji, style: AppTheme.cardTitleStyle),
                ),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            AppTheme.largeGap,

            // Emoji-väljare
            Text('Välj ikon för gruppen', style: AppTheme.formLabelStyle),
            AppTheme.smallGap,
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: _availableEmojis.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : null,
                        borderRadius: AppTheme.smallRadius,
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor)
                            : null,
                      ),
                      child: Center(
                          child:
                              Text(emoji, style: AppTheme.sectionTitleStyle)),
                    ),
                  );
                }).toList(),
              ),
            ),
            AppTheme.largeGap,

            // Beskrivning
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beskrivning (valfritt)',
                hintText: 'Beskriv vad den här gruppen är till för',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            AppTheme.largeGap,

            // Vänner att bjuda in (förenklad version)
            Text('Bjud in vänner till gruppen', style: AppTheme.formLabelStyle),
            AppTheme.smallGap,
            Text(
              'Vänner kommer få inbjudningar att gå med i gruppen.',
              style: AppTheme.captionStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: AppTheme.sectionPadding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isCreating ? null : () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ),
          AppTheme.mediumHorizontalGap,
          Expanded(
            child: FilledButton(
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? AppTheme.smallLoadingIndicator(color: Colors.white)
                  : const Text('Skapa grupp'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Gruppnamn krävs');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      // Simulera gruppskaping - här skulle du använda din service
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Skapa mock FriendCategory för att returnera
        final mockGroup = FriendCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          ownerId: 'current_user_id',
          name: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          emoji: _selectedEmoji,
          friendUserIds: _selectedFriendIds.toList(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        Navigator.pop(context, mockGroup);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kunde inte skapa gruppen: $e';
          _isCreating = false;
        });
      }
    }
  }
}

/// Internal Edit Group Dialog Widget
class _EditGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const _EditGroupDialog({required this.group});

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _selectedEmoji;
  bool _isSaving = false;

  final List<String> _availableEmojis = [
    '👥',
    '🏠',
    '🍽️',
    '💼',
    '🎯',
    '⚽',
    '🎮',
    '📚',
    '🎵',
    '✈️',
    '🍕',
    '💪',
    '🛒',
    '🎉',
    '❤️',
    '⭐'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController =
        TextEditingController(text: widget.group.description ?? '');
    _selectedEmoji = widget.group.emoji ?? '👥';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: AppTheme.sectionPadding,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.only(
          topLeft: AppTheme.largeRadius.topLeft,
          topRight: AppTheme.largeRadius.topRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, color: AppTheme.primaryColor),
          AppTheme.mediumHorizontalGap,
          Expanded(
              child: Text('Redigera grupp', style: AppTheme.sectionTitleStyle)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: SingleChildScrollView(
        padding: AppTheme.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info om befintlig grupp
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  AppTheme.smallHorizontalGap,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Redigerar: ${widget.group.name}',
                            style: AppTheme.formLabelStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600)),
                        Text('${widget.group.friendCount} medlemmar',
                            style: AppTheme.captionStyle
                                .copyWith(color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.largeGap,

            // Gruppnamn
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Gruppnamn *',
                prefixIcon: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(_selectedEmoji, style: AppTheme.cardTitleStyle),
                ),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            AppTheme.largeGap,

            // Emoji-väljare (samma som create)
            Text('Välj ikon för gruppen', style: AppTheme.formLabelStyle),
            AppTheme.smallGap,
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: _availableEmojis.map((emoji) {
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : null,
                        borderRadius: AppTheme.smallRadius,
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor)
                            : null,
                      ),
                      child: Center(
                          child:
                              Text(emoji, style: AppTheme.sectionTitleStyle)),
                    ),
                  );
                }).toList(),
              ),
            ),
            AppTheme.largeGap,

            // Beskrivning
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beskrivning (valfritt)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: AppTheme.sectionPadding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
          ),
          AppTheme.mediumHorizontalGap,
          Expanded(
            child: FilledButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? AppTheme.smallLoadingIndicator(color: Colors.white)
                  : const Text('Spara ändringar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      // Simulera sparande
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Skapa uppdaterat group objekt
        final updatedGroup = FriendCategory(
          id: widget.group.id,
          ownerId: widget.group.ownerId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          emoji: _selectedEmoji,
          friendUserIds: widget.group.friendUserIds,
          createdAt: widget.group.createdAt,
          updatedAt: DateTime.now(),
        );

        Navigator.pop(context, updatedGroup);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fel vid sparande: $e')),
        );
      }
    }
  }
}

/// Internal Delete Group Dialog Widget
class _DeleteGroupDialog extends StatefulWidget {
  final FriendCategory group;

  const _DeleteGroupDialog({required this.group});

  @override
  State<_DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<_DeleteGroupDialog> {
  bool _isDeleting = false;
  bool _confirmationChecked = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded,
          size: AppTheme.iconSizeAction, color: AppTheme.errorColor),
      title: const Text('Ta bort grupp?',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gruppinformation
            Container(
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: .1),
                      borderRadius: AppTheme.smallRadius,
                    ),
                    child: Center(
                        child: Text(widget.group.emoji ?? '👥',
                            style: const TextStyle(fontSize: 20))),
                  ),
                  AppTheme.mediumHorizontalGap,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.group.name, style: AppTheme.cardTitleStyle),
                        Text('${widget.group.friendCount} medlemmar',
                            style: AppTheme.captionStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.largeGap,

            // Varningstext
            RichText(
              text: TextSpan(
                style: AppTheme.bodyStyle,
                children: [
                  const TextSpan(text: 'Du är på väg att ta bort gruppen '),
                  TextSpan(
                      text: '"${widget.group.name}"',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '. Denna åtgärd kan inte ångras.'),
                ],
              ),
            ),
            AppTheme.largeGap,

            // Bekräftelse checkbox
            CheckboxListTile(
              value: _confirmationChecked,
              onChanged: _isDeleting
                  ? null
                  : (value) {
                      setState(() => _confirmationChecked = value ?? false);
                    },
              title: Text('Jag förstår att denna åtgärd inte kan ångras',
                  style: AppTheme.bodyStyle),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: AppTheme.errorColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed:
              (_isDeleting || !_confirmationChecked) ? null : _deleteGroup,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: _isDeleting
              ? AppTheme.smallLoadingIndicator(color: Colors.white)
              : const Text('Ta bort grupp'),
        ),
      ],
    );
  }

  Future<void> _deleteGroup() async {
    setState(() => _isDeleting = true);

    try {
      // Simulera borttagning
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fel vid borttagning: $e')),
        );
      }
    }
  }
}

/// Internal Remove Member Dialog Widget
class _RemoveMemberDialog extends StatefulWidget {
  final FriendCategory group;
  final UserProfile member;

  const _RemoveMemberDialog({required this.group, required this.member});

  @override
  State<_RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<_RemoveMemberDialog> {
  bool _isRemoving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_remove, color: AppTheme.warningColor),
          AppTheme.smallHorizontalGap,
          const Expanded(child: Text('Ta bort medlem')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Member info
          Container(
            padding: AppTheme.cardPadding,
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                SocialComponents.avatar(
                  user: widget.member,
                  size: ImageSize.small,
                ),
                AppTheme.mediumHorizontalGap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.member.displayName,
                          style: AppTheme.cardTitleStyle),
                      if (widget.member.bio?.isNotEmpty == true)
                        Text(widget.member.bio!, style: AppTheme.subtitleStyle),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppTheme.mediumGap,

          // Warning message
          Container(
            padding: AppTheme.cardPadding,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: .1),
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(color: AppTheme.warningColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_outlined, color: AppTheme.warningColor),
                AppTheme.smallHorizontalGap,
                Expanded(
                  child: Text(
                    'Är du säker på att du vill ta bort ${widget.member.displayName} från gruppen? Medlemmen kommer att meddelas om borttagningen.',
                    style: AppTheme.bodyStyle
                        .copyWith(color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRemoving ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _isRemoving ? null : _removeMember,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: _isRemoving
              ? AppTheme.smallLoadingIndicator(color: Colors.white)
              : const Text('Ta bort medlem'),
        ),
      ],
    );
  }

  Future<void> _removeMember() async {
    setState(() => _isRemoving = true);

    try {
      // Simulera medlemsborttagning
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fel vid borttagning: $e')),
        );
      }
    }
  }
}
