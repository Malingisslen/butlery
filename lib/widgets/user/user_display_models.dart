// lib/widgets/user/user_display_models.dart
// Data models, enums, and core data structures for user display components

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Image Size enum
enum ImageSize {
  small, // 32px
  medium, // 48px
  large, // 80px
  extraLarge, // 120px
  card, // 70px
  hero, // 200px
  thumbnail, // 60px
  custom, // Anpassad storlek
}

/// User Status enum
enum UserStatus { online, offline, away, busy }

/// Optimerad User Display Data class
class UserDisplayData {
  final String id;
  final String displayName;
  final String? email;
  final String? imageUrl;
  final String? subtitle;
  final String? description;
  final bool isOnline;
  final DateTime? lastSeen;
  final Map<String, dynamic>? metadata;

  const UserDisplayData({
    required this.id,
    required this.displayName,
    this.email,
    this.imageUrl,
    this.subtitle,
    this.description,
    this.isOnline = false,
    this.lastSeen,
    this.metadata,
  });

  /// Optimerade factory constructors
  factory UserDisplayData.fromFirebaseUser(firebase_auth.User user) =>
      UserDisplayData(
        id: user.uid,
        displayName: user.displayName ?? 'Unknown',
        email: user.email,
        imageUrl: user.photoURL,
      );

  factory UserDisplayData.fromUserProfile(UserProfile userProfile) =>
      UserDisplayData(
        id: userProfile.uid,
        displayName: userProfile.displayName,
        email: userProfile.email,
        imageUrl: userProfile.avatarUrl,
        isOnline: userProfile.isOnline,
      );

  UserDisplayData copyWith({
    String? id,
    String? displayName,
    String? email,
    String? imageUrl,
    String? subtitle,
    String? description,
    bool? isOnline,
    DateTime? lastSeen,
    Map<String, dynamic>? metadata,
  }) =>
      UserDisplayData(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        imageUrl: imageUrl ?? this.imageUrl,
        subtitle: subtitle ?? this.subtitle,
        description: description ?? this.description,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        metadata: metadata ?? this.metadata,
      );
}

/// Optimerade Status Helper funktioner
class UserStatusHelper {
  static Color getStatusColor(BuildContext context, UserStatus status) {
    final cs = Theme.of(context).colorScheme;
    final bc = context.butleryColors;
    return switch (status) {
      UserStatus.online => bc.success,
      UserStatus.offline => cs.outline,
      UserStatus.away => bc.warning,
      UserStatus.busy => cs.error,
    };
  }

  static String getStatusText(UserStatus status) {
    return switch (status) {
      UserStatus.online => AppLocale.current.userStatusOnline,
      UserStatus.offline => AppLocale.current.userStatusOffline,
      UserStatus.away => AppLocale.current.userStatusAway,
      UserStatus.busy => AppLocale.current.userStatusBusy,
    };
  }

  static Icon getStatusIcon(BuildContext context, UserStatus status,
      {double? size}) {
    final iconSize = size ?? AppDimensions.iconSizeM;
    final color = getStatusColor(context, status);

    return switch (status) {
      UserStatus.online => Icon(Icons.circle, color: color, size: iconSize),
      UserStatus.offline =>
        Icon(Icons.circle_outlined, color: color, size: iconSize),
      UserStatus.away => Icon(Icons.schedule, color: color, size: iconSize),
      UserStatus.busy =>
        Icon(Icons.do_not_disturb, color: color, size: iconSize),
    };
  }
}
