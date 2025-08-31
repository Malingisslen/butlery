import 'package:flutter_test/flutter_test.dart';

// Import bootstrap components for isolated testing
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/performance_module.dart';
import 'package:butlery/core/di/modules/ui_module.dart';

import 'package:butlery/core/bootstrap/stages/platform_stage.dart';
import 'package:butlery/core/bootstrap/stages/core_stage.dart';
import 'package:butlery/core/bootstrap/stages/content_stage.dart';
import 'package:butlery/core/bootstrap/stages/social_stage.dart';
import 'package:butlery/core/bootstrap/stages/ui_stage.dart';

void main() {
  group('🔬 Stage-by-Stage Bootstrap Diagnostic', () {
    setUpAll(() {
      print(
          '🔬 DIAGNOSTIC: Isolating bootstrap components to find hanging point');
    });

    tearDown(() async {
      // Reset bootstrap state between tests
      try {
        final bootstrap = ApplicationBootstrap();
        await bootstrap.reset();
      } catch (e) {
        print('   ⚠️ Bootstrap reset failed: $e');
      }
    });

    testWidgets('🔍 Module Registration Test - Sequential Registration',
        (WidgetTester tester) async {
      print('🧪 TEST: Module Registration Performance');
      print(
          '   Testing each module individually to identify hanging module...');

      final bootstrap = ApplicationBootstrap();

      // Test each module individually
      final modules = [
        {'name': 'CoreModule', 'module': CoreModule()},
        {'name': 'ContentModule', 'module': ContentModule()},
        {'name': 'SocialModule', 'module': SocialModule()},
        {'name': 'MessagingModule', 'module': MessagingModule()},
        {'name': 'CollaborationModule', 'module': CollaborationModule()},
        {'name': 'PerformanceModule', 'module': PerformanceModule()},
        {'name': 'UIModule', 'module': UIModule()},
      ];

      for (final moduleInfo in modules) {
        final stopwatch = Stopwatch()..start();
        print('   📦 Testing ${moduleInfo['name']} registration...');

        try {
          bootstrap.registerModule(moduleInfo['module'] as dynamic);
          print(
              '   ✅ ${moduleInfo['name']} registered in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('   ❌ ${moduleInfo['name']} registration failed: $e');
          print(
              '   🚨 FOUND ISSUE: Module registration hanging on ${moduleInfo['name']}');
          break;
        }
      }
    });

    testWidgets('🔍 Stage Registration Test - Sequential Registration',
        (WidgetTester tester) async {
      print('🧪 TEST: Stage Registration Performance');
      print('   Testing each stage individually...');

      final bootstrap = ApplicationBootstrap();

      final stages = [
        {'name': 'PlatformStage', 'stage': PlatformStage()},
        {'name': 'CoreStage', 'stage': CoreStage()},
        {'name': 'ContentStage', 'stage': ContentStage()},
        {'name': 'SocialStage', 'stage': SocialStage()},
        {'name': 'UIStage', 'stage': UIStage()},
      ];

      for (final stageInfo in stages) {
        final stopwatch = Stopwatch()..start();
        print('   🎭 Testing ${stageInfo['name']} registration...');

        try {
          bootstrap.registerStage(stageInfo['stage'] as dynamic);
          print(
              '   ✅ ${stageInfo['name']} registered in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('   ❌ ${stageInfo['name']} registration failed: $e');
          print(
              '   🚨 FOUND ISSUE: Stage registration hanging on ${stageInfo['name']}');
          break;
        }
      }
    });

    testWidgets('🔍 DI Container Test - Module Configuration',
        (WidgetTester tester) async {
      print('🧪 TEST: DI Container Module Configuration');
      print('   Testing module configuration to identify hanging module...');

      final bootstrap = ApplicationBootstrap();

      // Register minimal modules first
      bootstrap.registerModule(CoreModule());

      print('   ⚙️ Testing DI container initialization...');
      final stopwatch = Stopwatch()..start();

      try {
        // Test with timeout to detect hangs
        await bootstrap.container
            .initialize()
            .timeout(const Duration(seconds: 30));
        print(
            '   ✅ DI container initialized in ${stopwatch.elapsedMilliseconds}ms');
      } catch (e) {
        print('   ❌ DI container initialization timeout: $e');
        print(
            '   🚨 FOUND ISSUE: DI container hanging during module configuration');
        print(
            '   💡 Likely cause: One of the module.configure() methods is hanging');

        // Try to get more specific info
        print('   🔍 Analyzing container state...');
        try {
          final healthReport = await bootstrap.container
              .checkHealth()
              .timeout(const Duration(seconds: 5));
          print('   📊 Container health: ${healthReport.isHealthy}');
        } catch (healthError) {
          print('   ⚠️ Container health check also timed out: $healthError');
        }
      }
    });

    testWidgets('🔍 Individual Stage Execution Test',
        (WidgetTester tester) async {
      print('🧪 TEST: Individual Stage Execution');
      print('   Testing each stage execution to find hanging stage...');

      // Test each stage individually without full bootstrap
      final stages = [
        PlatformStage(),
        CoreStage(),
        ContentStage(),
        SocialStage(),
        UIStage(),
      ];

      for (final stage in stages) {
        print('   🎭 Testing ${stage.name} stage execution...');
        final stopwatch = Stopwatch()..start();

        try {
          // Execute stage with its configured timeout
          await stage.execute().timeout(stage.timeout);
          print(
              '   ✅ ${stage.name} executed in ${stopwatch.elapsedMilliseconds}ms (timeout: ${stage.timeout.inSeconds}s)');
        } catch (e) {
          print('   ❌ ${stage.name} execution failed: $e');
          print(
              '   🚨 FOUND ISSUE: Stage ${stage.name} hanging during execution');
          print('   📊 Stage details:');
          print('      - Timeout: ${stage.timeout}');
          print('      - Priority: ${stage.priority}');
          print('      - Optional: ${stage.isOptional}');
          print('      - Required modules: ${stage.requiredModules}');
          break;
        }
      }
    });

    testWidgets('🔍 Full Bootstrap Sequence with Detailed Logging',
        (WidgetTester tester) async {
      print('🧪 TEST: Full Bootstrap Sequence Analysis');
      print('   Running complete bootstrap with detailed phase tracking...');

      final bootstrap = ApplicationBootstrap();
      final overallStopwatch = Stopwatch()..start();

      try {
        print('   📦 Phase 1: Module registration...');
        final moduleStopwatch = Stopwatch()..start();

        final modules = [
          CoreModule(),
          ContentModule(),
          SocialModule(),
          MessagingModule(),
          CollaborationModule(),
          PerformanceModule(),
          UIModule(),
        ];

        bootstrap.registerModules(modules);
        print(
            '   ✅ Modules registered in ${moduleStopwatch.elapsedMilliseconds}ms');

        print('   🎭 Phase 2: Stage registration...');
        final stageStopwatch = Stopwatch()..start();

        final stages = [
          PlatformStage(),
          CoreStage(),
          ContentStage(),
          SocialStage(),
          UIStage(),
        ];

        bootstrap.registerStages(stages);
        print(
            '   ✅ Stages registered in ${stageStopwatch.elapsedMilliseconds}ms');

        print('   🚀 Phase 3: Full initialization...');
        final initStopwatch = Stopwatch()..start();

        // This is where the hang likely occurs - using public API
        await ApplicationBootstrap.initialize(
          modules: modules,
          stages: stages,
        ).timeout(const Duration(seconds: 45));

        print(
            '   ✅ Full initialization completed in ${initStopwatch.elapsedMilliseconds}ms');
        print(
            '   🎉 TOTAL BOOTSTRAP TIME: ${overallStopwatch.elapsedMilliseconds}ms');

        if (overallStopwatch.elapsedMilliseconds > 5000) {
          print('   ⚠️ PERFORMANCE ISSUE: Bootstrap took >5 seconds');
        }
      } catch (e) {
        print(
            '   ❌ Bootstrap sequence failed after ${overallStopwatch.elapsedMilliseconds}ms');
        print(
            '   🚨 CONFIRMED HANG LOCATION: During bootstrap._performInitialization()');
        print(
            '   💡 This confirms the production issue is in the initialization sequence');

        // Emergency diagnostic
        print('   🔍 Emergency state check...');
        print('      - Is initialized: ${bootstrap.isInitialized}');
        print('      - Is initializing: ${bootstrap.isInitializing}');
      }
    });
  });
}
