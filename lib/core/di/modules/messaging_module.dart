/// Messaging module for direct messaging and notifications.
/// This module handles all messaging-related functionality including:
/// - Direct messaging between users
/// - Group conversations
/// - Push notifications via FCM
/// - Message status tracking
/// - Typing indicators
/// Depends on Core Module and Social Module for foundational services.
library;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Dependencies from Core Module
import 'package:butlery/repositories/interfaces/auth_repository.dart';

// Dependencies from Social Module (for notifications)
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';

// Messaging repositories and interfaces
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';

// Messaging services
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/presence_service.dart';

// Firestore repository
import 'package:butlery/repositories/firestore_repository.dart';

// Import dependency modules
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';

/// Messaging module providing direct messaging and notification services.
/// This module handles all messaging functionality and depends on both
/// Core and Social modules. It provides:
/// - Direct messaging between users
/// - Group conversation management
/// - Message status tracking and delivery
/// - Typing indicators and real-time features
/// - Push notification integration
/// - Message history and synchronization
class MessagingModule implements DIModule {
  @override
  String get name => 'Messaging';

  @override
  List<Type> get dependencies => [CoreModule, SocialModule];

  @override
  List<Type> get provides => [
        MessagingRepository,
        MessagingService,
        PresenceService,
        NotificationsRepository, // Also provides notifications repository
      ];

  @override
  int get priority => 30; // After Core (1), Content (10), and Social (20)

  @override
  Future<void> configure(GetIt container) async {
    if (kDebugMode) {
      debugPrint('🔧 [MessagingModule] Configuring messaging services...');
    }

    try {
      // ==================== MESSAGING REPOSITORIES ====================

      // Messaging repository for direct messages and conversations
      container.registerSingleton<MessagingRepository>(
        FirebaseMessagingRepository(),
      );

      // Notifications repository (if not already registered by Social Module)
      if (!container.isRegistered<NotificationsRepository>()) {
        container.registerSingleton<NotificationsRepository>(
          FirebaseNotificationsRepository(
              authRepository: container<AuthRepository>()),
        );
      }

      // ==================== MESSAGING SERVICES ====================

      // MessagingService - handles direct messaging with FCM integration
      container.registerSingleton<MessagingService>(MessagingService(
        messagingRepository: container<MessagingRepository>(),
        authRepository: container<AuthRepository>(),
      ));

      // PresenceService - handles online/offline status and typing indicators
      container.registerSingleton<PresenceService>(PresenceService(
        firestoreRepository: container<FirestoreRepository>(),
        authRepository: container<AuthRepository>(),
      ));

      if (kDebugMode) {
        debugPrint(
            '✅ [MessagingModule] Configured messaging, presence and notifications services');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure messaging services',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    try {
      final container = GetIt.instance;

      // MessagingService doesn't require explicit initialization in current implementation
      // but we validate it's accessible and functional
      final messagingService = container<MessagingService>();
      messagingService.toString(); // Basic validation

      // Validate messaging repository
      final messagingRepository = container<MessagingRepository>();
      messagingRepository.toString(); // Basic validation

      // Initialize PresenceService for online/offline tracking
      final presenceService = container<PresenceService>();
      await presenceService.initialize();

      if (kDebugMode) {
        debugPrint('✅ [MessagingModule] Initialized presence tracking');
      }
    } catch (e) {
      throw DIModuleException(
        name,
        'initialization',
        'Failed to initialize messaging services',
        e,
      );
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Check that all messaging services are registered and accessible
      final services = <String, dynamic>{
        'MessagingRepository': container<MessagingRepository>(),
        'MessagingService': container<MessagingService>(),
        'PresenceService': container<PresenceService>(),
      };

      // Include NotificationsRepository if it was registered by this module
      if (container.isRegistered<NotificationsRepository>()) {
        services['NotificationsRepository'] =
            container<NotificationsRepository>();
      }

      // Perform health checks on services that support it
      for (final entry in services.entries) {
        final service = entry.value;

        if (service is HealthCheckable) {
          final isHealthy = await service.healthCheck();
          if (!isHealthy) {
            if (kDebugMode) {
              debugPrint(
                  '❌ [MessagingModule] Health check failed for ${entry.key}');
            }
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          if (kDebugMode) {
            debugPrint('❌ [MessagingModule] Service ${entry.key} is null');
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [MessagingModule] Health check failed: $e');
      }
      return false;
    }
  }
}

/// Messaging module factory for easy instantiation.
class MessagingModuleFactory {
  /// Create a new MessagingModule instance.
  static MessagingModule create() => MessagingModule();

  /// Create MessagingModule with custom configuration.
  static MessagingModule createWithConfig({
    bool enablePushNotifications = true,
    bool enableTypingIndicators = true,
    bool enableMessageStatus = true,
    bool enableGroupMessaging = true,
  }) {
    // For now, return standard module
    // In future, this could customize the module based on config
    return MessagingModule();
  }
}
