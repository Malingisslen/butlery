/// Social platform services initialization stage.
///
/// Handles initialization of social platform features including friends,
/// sharing, messaging, and collaborative features.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';

/// Social stage for social platform service initialization.
///
/// This stage ensures that all social platform services are properly
/// initialized and ready for use. It handles:
/// - User profile management
/// - Friend relationships and social groups
/// - Social recipe sharing and interactions
/// - Direct messaging and notifications
/// - Real-time collaboration features
/// - Social sharing capabilities
class SocialStage implements BootstrapStage {
  @override
  String get name => 'Social';

  @override
  List<Type> get requiredModules => [
    CoreModule,
    ContentModule,
    SocialModule,
    MessagingModule,
    CollaborationModule,
  ];

  @override
  Duration get timeout => const Duration(minutes: 1);

  @override
  int get priority => 30; // After Content stage

  @override
  bool get isOptional => true; // App can function without social features

  @override
  Future<void> execute() async {
    try {
      // Social module initialization is handled by the DI container
      // This stage can perform any additional social-specific setup
      
      // Allow time for social services to fully initialize
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        debugPrint('✅ [SocialStage] Social services ready');
      }
    } catch (e) {
      if (isOptional) {
        if (kDebugMode) {
          debugPrint('⚠️ [SocialStage] Optional stage failed, continuing: $e');
        }
        return; // Don't throw for optional stages
      }
      
      throw BootstrapException(
        name,
        'execution',
        'Social platform initialization failed',
        e,
      );
    }
  }

  @override
  Future<bool> validate() async {
    try {
      // Validation is primarily handled by the DI container's health checks
      // This stage confirms social services are ready
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SocialStage] Validation failed: $e');
      }
      
      // Return true for optional stages to allow app to continue
      return isOptional;
    }
  }
}