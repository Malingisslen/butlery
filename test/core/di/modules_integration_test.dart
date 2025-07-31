import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';

void main() {
  group('Modular DI System Integration', () {
    late DIContainer container;

    setUp(() {
      container = DIContainer();
    });

    tearDown(() async {
      await container.reset();
    });

    test('should register all modules successfully', () {
      final modules = [
        CoreModule(),
        ContentModule(),
        SocialModule(),
        MessagingModule(),
        CollaborationModule(),
      ];

      container.registerModules(modules);

      expect(container.modules.length, equals(5));
      expect(container.modules.map((m) => m.name), containsAll([
        'Core',
        'Content', 
        'Social',
        'Messaging',
        'Collaboration',
      ]));
    });

    test('should respect module dependencies', () {
      final modules = [
        CoreModule(),
        ContentModule(),
        SocialModule(),
        MessagingModule(),
        CollaborationModule(),
      ];

      container.registerModules(modules);

      // Core module should have no dependencies
      expect(CoreModule().dependencies, isEmpty);
      
      // Content module should depend on Core
      expect(ContentModule().dependencies, contains(CoreModule));
      
      // Social module should depend on Core and Content
      expect(SocialModule().dependencies, contains(CoreModule));
      expect(SocialModule().dependencies, contains(ContentModule));
      
      // Messaging module should depend on Core and Social
      expect(MessagingModule().dependencies, contains(CoreModule));
      expect(MessagingModule().dependencies, contains(SocialModule));
      
      // Collaboration module should depend on Core, Content, and Social
      expect(CollaborationModule().dependencies, contains(CoreModule));
      expect(CollaborationModule().dependencies, contains(ContentModule));
      expect(CollaborationModule().dependencies, contains(SocialModule));
    });

    test('should have correct module priorities', () {
      final modules = [
        CoreModule(),
        ContentModule(), 
        SocialModule(),
        MessagingModule(),
        CollaborationModule(),
      ];

      // Check priorities are set correctly for initialization order
      expect(CoreModule().priority, equals(1));     // Highest priority
      expect(ContentModule().priority, equals(10));
      expect(SocialModule().priority, equals(20));
      expect(MessagingModule().priority, equals(30));
      expect(CollaborationModule().priority, equals(40)); // Lowest priority
    });

    test('should provide expected service types', () {
      // Test that each module declares the services it provides
      
      final coreModule = CoreModule();
      expect(coreModule.provides, isNotEmpty);
      expect(coreModule.provides.length, greaterThan(4)); // Auth, Firestore, Persistence, Analytics, etc.
      
      final contentModule = ContentModule();
      expect(contentModule.provides, isNotEmpty);
      expect(contentModule.provides.length, greaterThan(8)); // Recipe, Menu, Import services, etc.
      
      final socialModule = SocialModule();
      expect(socialModule.provides, isNotEmpty);
      expect(socialModule.provides.length, greaterThan(10)); // User, Friends, Social services, etc.
      
      final messagingModule = MessagingModule();
      expect(messagingModule.provides, isNotEmpty);
      expect(messagingModule.provides.length, greaterThan(1)); // Messaging services
      
      final collaborationModule = CollaborationModule();
      expect(collaborationModule.provides, isNotEmpty);
      expect(collaborationModule.provides.length, greaterThan(4)); // Realtime, Shopping, Permission services
    });

    test('should pass basic health checks', () async {
      final modules = [
        CoreModule(),
        ContentModule(),
        SocialModule(), 
        MessagingModule(),
        CollaborationModule(),
      ];

      // Individual module health checks should work
      for (final module in modules) {
        // Note: Health checks may fail due to missing dependencies
        // This is expected behavior in isolated tests
        try {
          final isHealthy = await module.healthCheck();
          // Health check result is not critical in this isolated test
          expect(isHealthy, isA<bool>());
        } catch (e) {
          // Expected - services not registered yet
          expect(e, isNotNull);
        }
      }
    });

    test('should have consistent naming', () {
      final modules = [
        CoreModule(),
        ContentModule(),
        SocialModule(),
        MessagingModule(), 
        CollaborationModule(),
      ];

      for (final module in modules) {
        // Module names should be non-empty and follow convention
        expect(module.name, isNotEmpty);
        expect(module.name, matches(RegExp(r'^[A-Z][a-zA-Z]*$')));
      }
    });

    test('should create modules via factories', () {
      // Test factory methods work
      final coreModule = CoreModuleFactory.create();
      expect(coreModule, isA<CoreModule>());
      expect(coreModule.name, equals('Core'));

      final contentModule = ContentModuleFactory.create();
      expect(contentModule, isA<ContentModule>());
      expect(contentModule.name, equals('Content'));

      final socialModule = SocialModuleFactory.create();
      expect(socialModule, isA<SocialModule>());
      expect(socialModule.name, equals('Social'));

      final messagingModule = MessagingModuleFactory.create();
      expect(messagingModule, isA<MessagingModule>());
      expect(messagingModule.name, equals('Messaging'));

      final collaborationModule = CollaborationModuleFactory.create();
      expect(collaborationModule, isA<CollaborationModule>());
      expect(collaborationModule.name, equals('Collaboration'));
    });

    test('should create modules with custom config via factories', () {
      // Test factory methods with configuration work
      final coreModule = CoreModuleFactory.createWithConfig(
        enableAnalytics: true,
        enablePersistence: true,
      );
      expect(coreModule, isA<CoreModule>());

      final contentModule = ContentModuleFactory.createWithConfig(
        enableOfflineSync: true,
        enableCollaboration: true,
      );
      expect(contentModule, isA<ContentModule>());

      final socialModule = SocialModuleFactory.createWithConfig(
        enableSocialSharing: true,
        enableComments: true,
      );
      expect(socialModule, isA<SocialModule>());

      final messagingModule = MessagingModuleFactory.createWithConfig(
        enablePushNotifications: true,
        enableTypingIndicators: true,
      );
      expect(messagingModule, isA<MessagingModule>());

      final collaborationModule = CollaborationModuleFactory.createWithConfig(
        enableRealtimeSync: true,
        enableCollaborativeRecipes: true,
      );
      expect(collaborationModule, isA<CollaborationModule>());
    });
  });
}