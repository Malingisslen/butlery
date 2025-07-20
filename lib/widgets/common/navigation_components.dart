// lib/widgets/common/navigation_components.dart

import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/recipe_unified.dart';
import '../../viewmodels/realtime/participant_tracker.dart';

// Import focused modules
import 'dialogs/recipe_selection_dialogs.dart';
import 'dialogs/confirmation_dialogs.dart';
import 'indicators/realtime_indicators.dart';

/// 🎯 UNIFIED NavigationComponents - API Facade för alla navigation patterns
/// 
/// Detta är en API facade som delegerar till fokuserade moduler:
/// - RecipeSelectionDialogs: Recipe selection dialogs
/// - ConfirmationDialogs: Confirmation dialogs
/// - RealtimeIndicators: Realtime indicators
/// 
/// Fördelar med denna approach:
/// - Enhetlig API för alla NavigationComponents
/// - Fokuserade moduler för bättre maintainability
/// - Bakåtkompatibilitet med befintlig kod
/// - Enkel att utöka med nya moduler
class NavigationComponents {
  // =====================================
  // 📱 RECIPE SELECTION DIALOGS
  // =====================================

  /// 🤝 Dialog för att välja recept att dela med en vän
  /// Replaces: RecipeSelectionDialog
  static Future<void> showRecipeSelector(
    BuildContext context, {
    required UserProfile friend,
  }) async {
    return RecipeSelectionDialogs.showRecipeSelector(
      context,
      friend: friend,
    );
  }

  /// 📋 Dialog för att välja recept för meny-kategori
  /// Replaces: MenuRecipeSelectionDialog
  static Future<List<Recipe>?> showMenuRecipeSelector(
    BuildContext context, {
    required String categoryName,
  }) async {
    return RecipeSelectionDialogs.showMenuRecipeSelector(
      context,
      categoryName: categoryName,
    );
  }

  // =====================================
  // 🔄 REALTIME INDICATORS
  // =====================================

  /// ✏️ Indikator för vem som redigerar just nu
  /// Replaces: EditIndicator
  static Widget editIndicator({
    required String editorName,
    String? editorId,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
  }) {
    return RealtimeIndicators.editIndicator(
      editorName: editorName,
      editorId: editorId,
      editingWhat: editingWhat,
      color: color,
      isVisible: isVisible,
      animationDuration: animationDuration,
    );
  }

  /// 👥 Lista över aktiva deltagare med management
  /// Replaces: ParticipantList
  static Widget participantList({
    required List<ParticipantActivity> activities,
    required String currentUserId,
    bool canManageParticipants = false,
    Function(String userId)? onRemoveParticipant,
    Function(String userId)? onChangePermission,
  }) {
    return RealtimeIndicators.participantList(
      activities: activities,
      currentUserId: currentUserId,
      canManageParticipants: canManageParticipants,
      onRemoveParticipant: onRemoveParticipant,
      onChangePermission: onChangePermission,
    );
  }

  /// 🌐 Connection status indikator
  /// Replaces: RealtimeStatusIndicator
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return RealtimeIndicators.realtimeStatus(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding,
    );
  }

  /// 📢 Expanderat status banner för större visningar
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return RealtimeIndicators.realtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }

  // =====================================
  // 💬 CONFIRMATION DIALOGS
  // =====================================

  /// ✅ Standard bekräftelse dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    Color? confirmColor,
  }) async {
    return ConfirmationDialogs.showConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: confirmColor,
    );
  }

  /// ⚠️ Destructive confirmation dialog (red confirm button)
  static Future<bool> showDestructiveConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Ta bort',
    String cancelText = 'Avbryt',
  }) async {
    return ConfirmationDialogs.showDestructiveConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// 🔄 Loading confirmation dialog
  static Future<bool> showLoadingConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Fortsätt',
    String cancelText = 'Avbryt',
  }) async {
    return ConfirmationDialogs.showLoadingConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// 📋 List selection confirmation dialog
  static Future<int?> showListSelectionDialog<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) itemBuilder,
    String? message,
    String cancelText = 'Avbryt',
  }) async {
    return ConfirmationDialogs.showListSelectionDialog<T>(
      context,
      title: title,
      items: items,
      itemBuilder: itemBuilder,
      message: message,
      cancelText: cancelText,
    );
  }

  /// 📝 Text input confirmation dialog
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    bool isRequired = false,
    int? maxLength,
  }) async {
    return ConfirmationDialogs.showTextInputDialog(
      context,
      title: title,
      message: message,
      initialValue: initialValue,
      hintText: hintText,
      confirmText: confirmText,
      cancelText: cancelText,
      isRequired: isRequired,
      maxLength: maxLength,
    );
  }
}