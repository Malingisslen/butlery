// lib/widgets/common/indicators/realtime_indicators.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/widgets/common/indicators/edit_indicator_widget.dart';
import 'package:butlery/widgets/common/indicators/participant_list_widget.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';

/// Realtime indicators facade for collaborative features
/// This facade provides a unified interface to realtime indicator widgets:
/// - EditIndicatorWidget: Shows active editor
/// - ParticipantListWidget: Shows all participants
/// - RealtimeStatusWidget: Shows connection status
/// - RealtimeStatusBanner: Shows offline banner
/// **SRP Compliance:** This file follows the facade pattern - it delegates
/// to specialized widget modules rather than implementing widgets directly.
class RealtimeIndicators {
  /// Indicator showing who is currently editing
  static Widget editIndicator({
    required String editorName,
    String? editorId,
    required String editingWhat,
    Color? color,
    bool isVisible = true,
    Duration animationDuration = AppDimensions.animationDurationCommon,
  }) {
    return EditIndicatorWidget(
      editorName: editorName,
      editorId: editorId,
      editingWhat: editingWhat,
      color: color,
      isVisible: isVisible,
      animationDuration: animationDuration,
    );
  }

  /// List of active participants with management
  static Widget participantList({
    required List<ParticipantActivity> activities,
    required String currentUserId,
    bool canManageParticipants = false,
    Function(String userId)? onRemoveParticipant,
    Function(String userId)? onChangePermission,
  }) {
    return ParticipantListWidget(
      activities: activities,
      currentUserId: currentUserId,
      canManageParticipants: canManageParticipants,
      onRemoveParticipant: onRemoveParticipant,
      onChangePermission: onChangePermission,
    );
  }

  /// 🌐 Connection status indikator
  static Widget realtimeStatus({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    bool showText = false,
    EdgeInsets? padding,
  }) {
    return RealtimeStatusWidget(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      showText: showText,
      padding: padding,
    );
  }

  /// Expanded status banner for larger displays
  static Widget realtimeStatusBanner({
    required bool isOnline,
    required String statusDescription,
    required String statusEmoji,
    VoidCallback? onRetry,
  }) {
    return RealtimeStatusBanner(
      isOnline: isOnline,
      statusDescription: statusDescription,
      statusEmoji: statusEmoji,
      onRetry: onRetry,
    );
  }
}
