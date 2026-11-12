import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';

/// Platform-level FCM setup: Android channels, the OS permission prompt and
/// debug logging of incoming messages.
class FcmPlatformSetup {
  FcmPlatformSetup._();

  static const String _generalChannelId = 'butlery_general';
  static const String _socialChannelId = 'butlery_social';
  static const String _messagingChannelId = 'butlery_messaging';

  static Future<void> initializeAndroidChannels(
    FlutterLocalNotificationsPlugin localNotifications, {
    required DidReceiveNotificationResponseCallback onTapped,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      AppLogger.info('🔔 Initializing Android notification channels...');

      final generalChannel = AndroidNotificationChannel(
        _generalChannelId,
        AppLocale.current.fcmChannelGeneralTitle,
        description: AppLocale.current.fcmChannelGeneralDescription,
        importance: Importance.defaultImportance,
      );

      final socialChannel = AndroidNotificationChannel(
        _socialChannelId,
        AppLocale.current.fcmChannelSocialTitle,
        description: AppLocale.current.fcmChannelSocialDescription,
        importance: Importance.high,
      );

      final messagingChannel = AndroidNotificationChannel(
        _messagingChannelId,
        AppLocale.current.fcmChannelMessagingTitle,
        description: AppLocale.current.fcmChannelMessagingDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(generalChannel);
        await androidPlugin.createNotificationChannel(socialChannel);
        await androidPlugin.createNotificationChannel(messagingChannel);
        AppLogger.success('✅ Android notification channels created');
      }

      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: onTapped,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to initialize notification channels: $e');
      // Non-critical — FCM still works with default channel
    }
  }

  static Future<NotificationSettings> requestPermissions(
    FirebaseMessaging messaging,
  ) async {
    try {
      AppLogger.info('🔔 Requesting notification permissions...');

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.info(
        '🔔 Notification permission status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.success('✅ Notification permissions granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        AppLogger.info('📋 Provisional notification permissions granted');
      } else {
        AppLogger.warning('⚠️ Notification permissions denied');
      }

      return settings;
    } catch (e) {
      AppLogger.error('❌ Failed to request notification permissions', e);
      rethrow;
    }
  }

  static void logMessageDetails(RemoteMessage message) {
    if (kDebugMode) {
      AppLogger.debug(
        '🔔 Message details: '
        'messageId=${message.messageId}, '
        'title=${message.notification?.title}, '
        'body=${message.notification?.body}, '
        'from=${message.from}, '
        'category=${message.category}',
      );
    }
  }
}
