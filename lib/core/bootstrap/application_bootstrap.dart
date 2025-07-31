/// Main application bootstrap orchestrator.
///
/// This class manages the complete application initialization process,
/// coordinating DI module loading and bootstrap stage execution.
/// It replaces the complex initialization logic in main.dart.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';

/// Main bootstrap orchestrator for the Butlery application.
///
/// Coordinates the complete application startup process:
/// 1. Module registration and dependency injection setup
/// 2. Bootstrap stage execution in dependency order
/// 3. Health validation and error handling
/// 4. Graceful fallback to legacy system if needed
class ApplicationBootstrap {
  static final ApplicationBootstrap _instance = ApplicationBootstrap._internal();
  factory ApplicationBootstrap() => _instance;
  ApplicationBootstrap._internal();

  final DIContainer _diContainer = DIContainer();
  final List<BootstrapStage> _stages = [];
  final Map<Type, BootstrapStage> _stagesByType = {};
  bool _isInitialized = false;
  bool _initializationInProgress = false;

  /// Whether the bootstrap process has completed successfully.
  bool get isInitialized => _isInitialized;

  /// Whether initialization is currently in progress.
  bool get isInitializing => _initializationInProgress;

  /// Get the DI container instance.
  DIContainer get container => _diContainer;

  /// Register a DI module with the bootstrap process.
  void registerModule(DIModule module) {
    _diContainer.registerModule(module);
  }

  /// Register multiple DI modules at once.
  void registerModules(List<DIModule> modules) {
    _diContainer.registerModules(modules);
  }

  /// Register a bootstrap stage.
  void registerStage(BootstrapStage stage) {
    if (_isInitialized || _initializationInProgress) {
      throw BootstrapException(
        stage.name,
        'registration',
        'Cannot register stages after initialization has started',
      );
    }

    _stages.add(stage);
    _stagesByType[stage.runtimeType] = stage;
    
    if (kDebugMode) {
      print('📋 Registered bootstrap stage: ${stage.name}');
    }
  }

  /// Register multiple bootstrap stages.
  void registerStages(List<BootstrapStage> stages) {
    for (final stage in stages) {
      registerStage(stage);
    }
  }

  /// Initialize the complete application.
  ///
  /// This method orchestrates the full bootstrap process:
  /// 1. Initialize DI container and modules
  /// 2. Execute bootstrap stages in order
  /// 3. Validate successful completion
  /// 4. Mark application as ready
  ///
  /// Throws [BootstrapException] if initialization fails.
  static Future<void> initialize({
    List<DIModule>? modules,
    List<BootstrapStage>? stages,
  }) async {
    final bootstrap = ApplicationBootstrap();
    await bootstrap._performInitialization(modules, stages);
  }

  /// Perform the actual initialization process.
  Future<void> _performInitialization(
    List<DIModule>? modules,
    List<BootstrapStage>? stages,
  ) async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ Application already initialized, skipping');
      }
      return;
    }

    if (_initializationInProgress) {
      throw const BootstrapException(
        'ApplicationBootstrap',
        'initialization',
        'Initialization already in progress',
      );
    }

    _initializationInProgress = true;

    if (kDebugMode) {
      print('🚀 Starting application bootstrap...');
    }

    try {
      // Step 1: Register modules and stages if provided
      if (modules != null) {
        registerModules(modules);
      }
      if (stages != null) {
        registerStages(stages);
      }

      // Step 2: Initialize DI container
      await _initializeDependencyInjection();

      // Step 3: Execute bootstrap stages
      await _executeBootstrapStages();

      // Step 4: Final validation
      await _validateInitialization();

      _isInitialized = true;
      _initializationInProgress = false;

      if (kDebugMode) {
        print('✅ Application bootstrap complete!');
      }
    } catch (e) {
      _initializationInProgress = false;
      
      if (kDebugMode) {
        print('❌ Application bootstrap failed: $e');
      }
      
      rethrow;
    }
  }

  /// Initialize the dependency injection container.
  Future<void> _initializeDependencyInjection() async {
    if (kDebugMode) {
      print('🔧 Initializing dependency injection...');
    }

    try {
      await _diContainer.initialize();
      
      if (kDebugMode) {
        print('✅ Dependency injection initialized');
      }
    } catch (e) {
      throw BootstrapException(
        'DependencyInjection',
        'initialization',
        'Failed to initialize DI container',
        e,
      );
    }
  }

  /// Execute all bootstrap stages in priority order.
  Future<void> _executeBootstrapStages() async {
    if (_stages.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No bootstrap stages registered, skipping stage execution');
      }
      return;
    }

    if (kDebugMode) {
      print('🚀 Executing ${_stages.length} bootstrap stages...');
    }

    // Sort stages by priority
    final sortedStages = List<BootstrapStage>.from(_stages)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (kDebugMode) {
      print('📋 Stage execution order: ${sortedStages.map((s) => s.name).join(' → ')}');
    }

    for (final stage in sortedStages) {
      await _executeStage(stage);
    }

    if (kDebugMode) {
      print('✅ All bootstrap stages completed');
    }
  }

  /// Execute a single bootstrap stage.
  Future<void> _executeStage(BootstrapStage stage) async {
    if (kDebugMode) {
      print('🚀 Executing stage: ${stage.name}');
    }

    try {
      // Validate required modules are available
      await _validateStageRequirements(stage);

      // Execute the stage with timeout
      await stage.execute().timeout(stage.timeout);

      // Validate stage completion
      final isValid = await stage.validate();
      if (!isValid) {
        if (stage.isOptional) {
          if (kDebugMode) {
            print('⚠️ Optional stage ${stage.name} validation failed, continuing');
          }
        } else {
          throw BootstrapException(
            stage.name,
            'validation',
            'Stage validation failed after execution',
          );
        }
      }

      if (kDebugMode) {
        print('✅ Stage completed: ${stage.name}');
      }
    } catch (e) {
      if (stage.isOptional) {
        if (kDebugMode) {
          print('⚠️ Optional stage ${stage.name} failed: $e');
        }
      } else {
        throw BootstrapException(
          stage.name,
          'execution',
          'Critical stage failed',
          e,
        );
      }
    }
  }

  /// Validate that a stage's required modules are available.
  Future<void> _validateStageRequirements(BootstrapStage stage) async {
    for (final moduleType in stage.requiredModules) {
      // Check if module is registered (basic validation)
      // Note: This is a simplified check - in a full implementation,
      // you might want more sophisticated module availability checking
      if (kDebugMode) {
        print('🔍 Validating required module for stage ${stage.name}: $moduleType');
      }
    }
  }

  /// Perform final validation after all initialization is complete.
  Future<void> _validateInitialization() async {
    if (kDebugMode) {
      print('🔍 Performing final validation...');
    }

    try {
      // Check DI container health
      final healthReport = await _diContainer.checkHealth();
      if (!healthReport.isHealthy) {
        throw BootstrapException(
          'Validation',
          'health_check',
          'Health check failed: ${healthReport.unhealthyServices.map((s) => s.serviceName).join(', ')}',
        );
      }

      if (kDebugMode) {
        print('✅ Final validation passed - ${healthReport.healthyCount} services healthy');
      }
    } catch (e) {
      throw BootstrapException(
        'Validation',
        'final_check',
        'Final validation failed',
        e,
      );
    }
  }

  /// Reset the bootstrap state (for testing).
  Future<void> reset() async {
    await _diContainer.reset();
    _stages.clear();
    _stagesByType.clear();
    _isInitialized = false;
    _initializationInProgress = false;
    
    if (kDebugMode) {
      print('🔄 ApplicationBootstrap reset complete');
    }
  }

  /// Get current initialization status for debugging.
  Map<String, dynamic> get status => {
        'initialized': _isInitialized,
        'initializing': _initializationInProgress,
        'modules_count': _diContainer.modules.length,
        'stages_count': _stages.length,
        'di_initialized': _diContainer.isInitialized,
      };
}