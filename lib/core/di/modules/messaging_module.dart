/// Messaging module for direct messaging and notifications.
/// This module handles all messaging-related functionality including:
/// - Direct messaging between users
/// - Group conversations
/// - Push notifications via FCM
/// - Message status tracking
/// - Typing indicators
/// Depends on Core Module and Social Module for foundational services.
library;

import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/di/interfaces/service_health.dart';

// Dependencies from Core Module
import 'package:butlery/repositories/interfaces/auth_repository.dart';

// Dependencies from Social Module (for notifications)
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/firebase/firebase_device_repository.dart';

// Messaging repositories and interfaces
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';

// Messaging services
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/messaging/message_reactions_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:butlery/services/notifications/notification_service.dart';

// Firestore repository
import 'package:butlery/repositories/firestore_repository.dart';

// Feature flags for subcollection participants
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

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
        MessageReactionsService,
        PresenceService,
        NotificationsRepository, // Also provides notifications repository
        NotificationHistoryRepository,
        NotificationBatchRepository,
        DeviceRepository,
        NotificationService,
      ];

  @override
  int get priority => 30; // After Core (1), Content (10), and Social (20)

  @override
  Future<void> configureUserScope(GetIt container) async {
    final appScope = GetIt.instance;

    container.registerLazySingleton<MessagingService>(
      () => MessagingService(
        messagingRepository: appScope<MessagingRepository>(),
        authRepository: appScope<AuthRepository>(),
        reactionsService: appScope<MessageReactionsService>(),
      ),
    );

    container.registerLazySingleton<PresenceService>(
      () => PresenceService(
        firestoreRepository: appScope<FirestoreRepository>(),
        authRepository: appScope<AuthRepository>(),
        database: FirebaseDatabase.instance,
      ),
      dispose: (s) => s.dispose(),
    );

    container.registerLazySingleton<NotificationService>(
      () => NotificationService(
        notificationsRepository: appScope<NotificationsRepository>(),
        authRepository: appScope<AuthRepository>(),
        historyRepository: appScope<NotificationHistoryRepository>(),
        batchRepository: appScope<NotificationBatchRepository>(),
        deviceRepository: appScope<DeviceRepository>(),
      ),
      dispose: (s) => s.resetForLogout(),
    );
  }

  @override
  Future<void> configure(GetIt container) async {
    try {
      // Messaging repository for direct messages and conversations
      container.registerLazySingleton<MessagingRepository>(
        () => FirebaseMessagingRepository(
          featureFlagService: container.isRegistered<FeatureFlagService>()
              ? container<FeatureFlagService>()
              : null,
        ),
      );

      // Notifications repository (if not already registered by Social Module)
      if (!container.isRegistered<NotificationsRepository>()) {
        container.registerLazySingleton<NotificationsRepository>(
          () => FirebaseNotificationsRepository(
              authRepository: container<AuthRepository>()),
        );
      }
      // MessageReactionsService - handles emoji reactions on messages
      container.registerLazySingleton<MessageReactionsService>(
        () => MessageReactionsService(
          firestoreRepository: container<FirestoreRepository>(),
          authRepository: container<AuthRepository>(),
        ),
      );

      // MessagingService, PresenceService, NotificationService: registered in configureUserScope

      // Notification history repository for dedup and delivery tracking
      container.registerLazySingleton<NotificationHistoryRepository>(
        () => FirebaseNotificationHistoryRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Device repository for FCM token and device management
      container.registerLazySingleton<DeviceRepository>(
        () => FirebaseDeviceRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // Notification batch repository for batch aggregation
      container.registerLazySingleton<NotificationBatchRepository>(
        () => FirebaseNotificationBatchRepository(
          authRepository: container<AuthRepository>(),
        ),
      );

      // NotificationService: registered in configureUserScope
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

      // Initialize NotificationService (non-critical — guarded so startup continues)
      try {
        final notificationService = container<NotificationService>();
        await notificationService.initialize();
      } catch (e) {
        // NotificationService initialization may fail (e.g. FCM not available on web)
        // but should not block app startup
      }

      // Validate MessageReactionsService is accessible
      final reactionsService = container<MessageReactionsService>();
      reactionsService.toString();
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
        'MessageReactionsService': container<MessageReactionsService>(),
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
            return false;
          }
        }

        // Basic validation - service is not null
        if (service == null) {
          return false;
        }
      }

      return true;
    } catch (e) {
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
