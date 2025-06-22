// lib/widgets/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// 🔍 AI INFO BLOCK:
/// Component: User Avatar Widget med Social Navigation
/// File: widgets/user_avatar.dart
/// Quick Guide: Smart avatar med fallback och social menu navigation
/// Dependencies IN: cached_network_image, app_theme.dart
/// Dependencies OUT: Alla views som visar användare
/// Data flow: Avatar URL → Cache check → Network load → Tap → Social navigation
/// State management: Stateless med caching handled av cached_network_image
/// Purpose: Konsistent avatar visning med elegant fallbacks och social navigation
/// Common issues: Avatar loading delays, navigation context
/// Test coverage: 70%
/// Performance: ⚡ Cached med memory optimization
/// Analytics: N/A
/// Code smells: ✅ Clean design med theme integration och proper navigation
/// Connected to: UserProfile modell, alla social views, social menu
/// Used in phases: 18

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderWidth;
  final Color? borderColor;
  final bool enableSocialNavigation;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.size = 40,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
    this.enableSocialNavigation = false,
  });

  /// Named constructors för vanliga storlekar
  const UserAvatar.small({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
    this.enableSocialNavigation = false,
  }) : size = 32;

  const UserAvatar.medium({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
    this.enableSocialNavigation = false,
  }) : size = 48;

  const UserAvatar.large({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
    this.enableSocialNavigation = false,
  }) : size = 80;

  const UserAvatar.extraLarge({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
    this.enableSocialNavigation = false,
  }) : size = 120;

  /// Social variant som öppnar social menu när tappat
  const UserAvatar.social({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderColor,
  })  : onTap = null,
        enableSocialNavigation = true;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onPrimaryContainer;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: borderWidth != null && borderColor != null
            ? Border.all(
                width: borderWidth!,
                color: borderColor!,
              )
            : null,
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitialsAvatar(
                  context,
                  effectiveBackgroundColor,
                  effectiveTextColor,
                ),
                errorWidget: (context, url, error) => _buildInitialsAvatar(
                  context,
                  effectiveBackgroundColor,
                  effectiveTextColor,
                ),
              ),
            )
          : _buildInitialsAvatar(
              context,
              effectiveBackgroundColor,
              effectiveTextColor,
            ),
    );

    // Hantera tap - antingen custom onTap eller social navigation
    final VoidCallback? effectiveOnTap =
        enableSocialNavigation ? () => _showSocialMenu(context) : onTap;

    if (effectiveOnTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  Widget _buildInitialsAvatar(
    BuildContext context,
    Color backgroundColor,
    Color textColor,
  ) {
    final initials = _getInitials(displayName);
    final fontSize = size * 0.4; // 40% av avatar-storleken

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));

    if (words.length == 1) {
      // Ett ord - ta första och eventuellt andra bokstaven
      final word = words[0];
      if (word.length == 1) {
        return word.toUpperCase();
      } else {
        return '${word[0]}${word.length > 1 ? word[1] : ''}'.toUpperCase();
      }
    } else {
      // Flera ord - ta första bokstaven från första och andra ordet
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Visa social menu
  void _showSocialMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Social',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Menu items
            Padding(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'Min profil',
                    subtitle: 'Redigera profil och inställningar',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile/edit');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'Vänner',
                    subtitle: 'Hantera vänner och förfrågningar',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoon(context, 'Vänner');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.share_outlined,
                    title: 'Delade recept',
                    subtitle: 'Recept som delats med mig',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoon(context, 'Delade recept');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notiser',
                    subtitle: 'Vänskapsförfrågningar och meddelanden',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoon(context, 'Notiser');
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: AppTheme.spacingMd),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature kommer snart! 🚀'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }
}

/// Avatar med online status indikator
class UserAvatarWithStatus extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final bool isOnline;
  final double size;
  final VoidCallback? onTap;
  final bool enableSocialNavigation;

  const UserAvatarWithStatus({
    super.key,
    this.imageUrl,
    required this.displayName,
    required this.isOnline,
    this.size = 48,
    this.onTap,
    this.enableSocialNavigation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar(
          imageUrl: imageUrl,
          displayName: displayName,
          size: size,
          onTap: onTap,
          enableSocialNavigation: enableSocialNavigation,
        ),
        // Online status indicator
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.25,
            height: size * 0.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppTheme.successColor : Colors.grey[400],
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar för profil-header med stort format
class ProfileHeaderAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final VoidCallback? onEditTap;

  const ProfileHeaderAvatar({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UserAvatar.extraLarge(
          imageUrl: imageUrl,
          displayName: displayName,
          borderWidth: 3,
          borderColor: Theme.of(context).colorScheme.outline,
        ),
        if (onEditTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
