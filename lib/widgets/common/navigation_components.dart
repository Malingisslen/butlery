/// Comprehensive navigation components facade providing unified interface for dialogs, indicators, and user interaction patterns.
/// This facade implements a centralized navigation and interaction system that provides consistent interface patterns
/// for recipe selection dialogs, confirmation dialogs, real-time collaboration indicators, and user interaction
/// workflows. It delegates to specialized navigation modules while maintaining unified API design and supporting
/// Swedish localization throughout all navigation and interaction scenarios.
/// **Architecture Integration:**
/// - Implements Facade Pattern for unified access to specialized navigation modules
/// - Provides consistent dialog and interaction patterns throughout the application
/// - Integrates with real-time collaboration system for live editing indicators
/// - Supports recipe selection workflows with social sharing capabilities
/// - Maintains responsive design patterns for various screen sizes and device orientations
/// **Navigation Categories:**
/// - **Recipe Selection**: Dialogs for selecting recipes for sharing and menu creation
/// - **Confirmation Dialogs**: Standard, destructive, loading, and input confirmation patterns
/// - **Real-time Indicators**: Live editing indicators, participant lists, and connection status
/// - **User Interaction**: Text input, list selection, and multi-choice interaction patterns
/// - **Collaborative Features**: Participant management and permission-based interactions
/// **Key Features:**
/// - Comprehensive dialog system with Swedish localization and consistent theming
/// - Real-time collaboration indicators with live participant tracking
/// - Recipe selection workflows integrated with social sharing capabilities
/// - Confirmation patterns for destructive actions with appropriate visual warnings
/// - Responsive design support for various screen sizes and interaction patterns
/// - Performance optimization through focused, specialized navigation modules
/// **Usage Examples:**
/// ```dart
/// // Recipe selection for sharing
/// await NavigationComponents.showRecipeSelector(
///   context,
///   friend: selectedFriend,
/// );
/// // Destructive confirmation dialog
/// final confirmed = await NavigationComponents.showDestructiveConfirmationDialog(
///   context,
///   title: 'Ta bort recept',
///   message: 'Detta kan inte ångras',
/// );
/// // Real-time editing indicator
/// NavigationComponents.editIndicator(
///   editorName: 'Anna',
///   editingWhat: 'ingredienser',
///   color: Theme.of(context).primaryColor,
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';

// Import focused modules
import 'package:butlery/widgets/common/dialogs/recipe_selection_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/indicators/realtime_indicators.dart';

/// Comprehensive navigation components facade implementing unified interface for dialogs, indicators, and user interaction patterns.
/// This class serves as the central access point for all navigation and interaction-related functionality
/// throughout the application, providing consistent interface patterns and delegating to specialized navigation
/// modules for optimal performance and maintainability. It supports Swedish localization, real-time collaboration,
/// and comprehensive user interaction workflows.
/// **Navigation Architecture:**
/// - **Modular Design**: Each navigation type is handled by a focused specialized module
/// - **Consistent API**: Unified method signatures and parameter patterns across all components
/// - **Swedish Localization**: Native Swedish language support throughout all navigation messaging
/// - **Real-time Integration**: Live collaboration features with participant tracking and editing indicators
/// - **Responsive Support**: Adaptive layouts for various screen sizes and device orientations
/// **Migration Support:**
/// This facade maintains full backward compatibility while providing improved organization,
/// performance, and consistency through the delegation pattern to specialized navigation modules.
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