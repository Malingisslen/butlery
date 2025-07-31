import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';

// Mock module for testing
class TestModule implements DIModule {
  @override
  String get name => 'Test';

  @override
  List<Type> get dependencies => [];

  @override
  List<Type> get provides => [String];

  @override
  int get priority => 100;

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<String>('test_service');
  }

  @override
  Future<void> initialize() async {
    // Test initialization
  }

  @override
  Future<bool> healthCheck() async {
    return true;
  }
}

class FailingModule implements DIModule {
  @override
  String get name => 'Failing';

  @override
  List<Type> get dependencies => [];

  @override
  List<Type> get provides => [];

  @override
  int get priority => 200;

  @override
  Future<void> configure(GetIt container) async {
    throw Exception('Configuration failed');
  }

  @override
  Future<void> initialize() async {
    throw Exception('Initialization failed');
  }

  @override
  Future<bool> healthCheck() async {
    return false;
  }
}

void main() {
  group('DIContainer', () {
    late DIContainer container;

    setUp(() {
      container = DIContainer();
    });

    tearDown(() async {
      await container.reset();
    });

    test('should register modules', () {
      final module = TestModule();
      container.registerModule(module);
      
      expect(container.modules.length, equals(1));
      expect(container.modules.first.name, equals('Test'));
    });

    test('should register multiple modules', () {
      final modules = [TestModule(), TestModule()];
      container.registerModules(modules);
      
      expect(container.modules.length, equals(2));
    });

    test('should initialize successfully with valid module', () async {
      final module = TestModule();
      container.registerModule(module);
      
      await container.initialize();
      
      expect(container.isInitialized, isTrue);
      expect(container.get<String>(), equals('test_service'));
    });

    test('should fail initialization with failing module', () async {
      final module = FailingModule();
      container.registerModule(module);
      
      expect(
        () async => await container.initialize(),
        throwsA(isA<DIModuleException>()),
      );
    });

    test('should perform health check', () async {
      final module = TestModule();
      container.registerModule(module);
      await container.initialize();
      
      final healthReport = await container.checkHealth();
      
      expect(healthReport.isHealthy, isTrue);
      expect(healthReport.totalCount, greaterThan(0));
    });

    test('should check service registration', () async {
      final module = TestModule();
      container.registerModule(module);
      await container.initialize();
      
      expect(container.isRegistered<String>(), isTrue);
      expect(container.isRegistered<int>(), isFalse);
    });

    test('should reset properly', () async {
      final module = TestModule();
      container.registerModule(module);
      await container.initialize();
      
      await container.reset();
      
      expect(container.isInitialized, isFalse);
      expect(container.modules.length, equals(0));
    });

    test('should prevent module registration after initialization', () async {
      final module1 = TestModule();
      container.registerModule(module1);
      await container.initialize();
      
      expect(
        () => container.registerModule(TestModule()),
        throwsA(isA<DIModuleException>()),
      );
    });
  });
}