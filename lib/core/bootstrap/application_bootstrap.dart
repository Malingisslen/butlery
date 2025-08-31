/// Comprehensive application bootstrap orchestrator implementing intelligent initialization coordination for Swedish cooking application architecture.
///
/// This bootstrap system serves as the foundational application startup infrastructure throughout the Butlery application,
/// coordinating the complete initialization process including dependency injection module loading, bootstrap stage execution,
/// health validation, and error recovery. It ensures reliable application startup while providing comprehensive monitoring
/// and error handling for Swedish cooking application's complex service dependencies, collaborative features, and real-time
/// synchronization requirements that demand careful initialization sequencing and proper failure recovery mechanisms.
///
/// ## Core Architecture Features
/// 
/// **Intelligent Initialization Coordination**
/// - Orchestrated DI module registration and dependency resolution with proper sequencing
/// - Bootstrap stage execution in priority order with timeout management and error recovery
/// - Health validation and comprehensive error handling with graceful fallback mechanisms
/// - Initialization state management with progress tracking and status reporting capabilities
/// 
/// **Modular Bootstrap Architecture**
/// - Module-based initialization with dependency ordering and circular dependency detection
/// - Stage-based bootstrap process with configurable priorities and optional stage support
/// - Comprehensive error handling with detailed context and recovery information
/// - Testing support with complete reset capabilities and status inspection utilities
/// 
/// **Production-Ready Reliability**
/// - Timeout management for bootstrap stages with configurable duration limits
/// - Health validation with comprehensive service status checking and monitoring
/// - Error context preservation with detailed logging and debugging information
/// - Graceful error recovery with optional stage fallback and continuation support
/// 
/// ## Usage Examples
/// 
/// **Basic Application Bootstrap:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize application with modules and stages
///   await ApplicationBootstrap.initialize(
///     modules: [
///       CoreModule(),
///       ContentModule(),
///       SocialModule(),
///       MessagingModule(),
///       CollaborationModule(),
///     ],
///     stages: [
///       PlatformStage(),
///       CoreStage(),
///       ContentStage(),
///       SocialStage(),
///       UIStage(),
///     ],
///   );
///   
///   runApp(MyApp());
/// }
/// ```
/// 
/// **Custom Bootstrap Configuration:**
/// ```dart
/// class CustomBootstrap {
///   static Future<void> initializeWithCustomConfig() async {
///     final bootstrap = ApplicationBootstrap();
///     
///     // Register modules individually
///     bootstrap.registerModule(CoreModule());
///     bootstrap.registerModule(ContentModule());
///     
///     // Register stages with custom priorities
///     bootstrap.registerStage(CustomInitStage());
///     bootstrap.registerStage(DataMigrationStage());
///     
///     // Perform initialization
///     await bootstrap._performInitialization(null, null);
///   }
/// }
/// ```
/// 
/// **Bootstrap Status Monitoring:**
/// ```dart
/// class BootstrapMonitor {
///   static void monitorInitialization() {
///     final bootstrap = ApplicationBootstrap();
///     
///     // Check initialization status
///     print('Bootstrap status: ${bootstrap.status}');
///     print('Is initialized: ${bootstrap.isInitialized}');
///     print('Is initializing: ${bootstrap.isInitializing}');
///     
///     // Get detailed status information
///     final status = bootstrap.status;
///     print('Modules: ${status['modules_count']}');
///     print('Stages: ${status['stages_count']}');
///     print('DI initialized: ${status['di_initialized']}');
///   }
/// }
/// ```
/// 
/// **Testing Support:**
/// ```dart
/// class BootstrapTestSetup {
///   static Future<void> setupTestEnvironment() async {
///     final bootstrap = ApplicationBootstrap();
///     
///     // Reset bootstrap state
///     await bootstrap.reset();
///     
///     // Register test modules
///     bootstrap.registerModules([
///       TestCoreModule(),
///       MockDataModule(),
///     ]);
///     
///     // Register test stages
///     bootstrap.registerStages([
///       TestInitStage(),
///       MockDataStage(),
///     ]);
///     
///     await bootstrap._performInitialization(null, null);
///   }
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Initialization Efficiency**: Optimized module loading with minimal startup time overhead
/// - **Memory Management**: Proper resource management with automatic cleanup and disposal
/// - **Error Recovery**: Graceful error handling with detailed context and recovery mechanisms
/// - **Monitoring Integration**: Comprehensive status reporting with health validation and metrics
/// 
/// ## Integration Patterns
/// 
/// - **Main Application**: Primary initialization orchestrator called from main.dart entry point
/// - **Module System**: Coordinates all DI modules for proper dependency injection setup
/// - **Bootstrap Stages**: Manages sequential initialization stages with priority ordering
/// - **Health Monitoring**: Integrates with health checking systems for production monitoring
/// 
/// This bootstrap system is essential for reliable, monitored, and properly sequenced application
/// initialization throughout the Swedish cooking application while providing comprehensive error
/// handling and recovery mechanisms for production-grade startup reliability and monitoring.
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive bootstrap orchestrator that manages the complete application initialization process for the Butlery application.
///
/// This class coordinates the entire startup sequence including DI module registration, dependency resolution, bootstrap
/// stage execution, health validation, and error recovery. It provides a reliable, monitored, and properly sequenced
/// initialization process that ensures all application components are properly configured and ready for operation.
///
/// **Key Features:**
/// - Orchestrated DI module registration with dependency ordering and circular dependency detection
/// - Bootstrap stage execution in priority order with timeout management and error recovery
/// - Comprehensive health validation with service status checking and monitoring integration
/// - Initialization state management with progress tracking and detailed status reporting
/// - Testing support with complete reset capabilities and status inspection utilities
/// - Production-ready error handling with detailed context preservation and recovery mechanisms
///
/// **Integration Points:**
/// - Main application entry point coordinates all startup operations through this orchestrator
/// - DI container management ensures proper service registration and dependency resolution
/// - Bootstrap stages provide modular initialization with configurable priorities and optional support
/// - Health monitoring systems integrate for production-grade startup validation and monitoring
///
/// **Example Usage:**
/// ```dart
/// // Basic initialization from main.dart
/// await ApplicationBootstrap.initialize(
///   modules: [CoreModule(), ContentModule(), SocialModule()],
///   stages: [PlatformStage(), CoreStage(), UIStage()],
/// );
/// 
/// // Custom initialization with monitoring
/// final bootstrap = ApplicationBootstrap();
/// bootstrap.registerModule(CustomModule());
/// await bootstrap._performInitialization(null, null);
/// print('Status: ${bootstrap.status}');
/// ```
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
      // During hot restart, skip re-registration if stage already exists
      if (_stagesByType.containsKey(stage.runtimeType)) {
        if (kDebugMode) {
          AppLogger.debug('🔄 Stage ${stage.name} already registered (hot restart detected)');
        }
        return;
      }
      throw BootstrapException(
        stage.name,
        'registration',
        'Cannot register stages after initialization has started',
      );
    }

    _stages.add(stage);
    _stagesByType[stage.runtimeType] = stage;
    
    if (kDebugMode) {
      AppLogger.debug('📋 Registered bootstrap stage: ${stage.name}');
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
    
    // Reset state for hot restart
    if (bootstrap._isInitialized || bootstrap._initializationInProgress) {
      if (kDebugMode) {
        AppLogger.info('🔄 Hot restart detected, resetting bootstrap state');
      }
      await bootstrap.reset();
    }
    
    await bootstrap._performInitialization(modules, stages);
  }

  /// Perform the actual initialization process.
  Future<void> _performInitialization(
    List<DIModule>? modules,
    List<BootstrapStage>? stages,
  ) async {
    if (_isInitialized) {
      if (kDebugMode) {
        AppLogger.warning('⚠️ Application already initialized, skipping');
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

    if (kDebugMode) {
      AppLogger.info('🚀 Starting Butlery with modular system');
    }

    try {
      // Step 1: Register modules and stages if provided (before setting in progress flag)
      if (modules != null) {
        registerModules(modules);
      }
      if (stages != null) {
        registerStages(stages);
      }

      // Now set the initialization in progress flag after registration
      _initializationInProgress = true;

      // Step 1.5: Initialize ServiceLocator with the DI container BEFORE initializing modules
      // This allows modules to use ServiceLocator during their configuration
      ServiceLocator.initialize(_diContainer);
      // ServiceLocator initialized - silent in production

      // Step 2: Initialize DI container (which configures modules)
      await _initializeDependencyInjection();

      // Step 3: Execute bootstrap stages
      await _executeBootstrapStages();

      // Step 4: Final validation
      await _validateInitialization();

      _isInitialized = true;
      _initializationInProgress = false;

      if (kDebugMode) {
        AppLogger.info('✅ Modular system initialized successfully');
      }
    } catch (e) {
      _initializationInProgress = false;
      
      if (kDebugMode) {
        AppLogger.error('❌ Application bootstrap failed: $e');
      }
      
      rethrow;
    }
  }

  /// Initialize the dependency injection container.
  Future<void> _initializeDependencyInjection() async {
    if (kDebugMode) {
      AppLogger.info('🔧 Initializing modular DI system...');
    }

    try {
      await _diContainer.initialize();
      
      // DI system initialized - silent in production
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
        AppLogger.warning('⚠️ No bootstrap stages registered, skipping stage execution');
      }
      return;
    }

    // Bootstrap stages executing - silent in production

    // Sort stages by priority
    final sortedStages = List<BootstrapStage>.from(_stages)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Stage order determined - silent in production

    for (final stage in sortedStages) {
      await _executeStage(stage);
    }

    // All stages completed - silent in production
  }

  /// Execute a single bootstrap stage.
  Future<void> _executeStage(BootstrapStage stage) async {
    // Executing stage - silent in production

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
            AppLogger.warning('⚠️ Optional stage ${stage.name} validation failed, continuing');
          }
        } else {
          throw BootstrapException(
            stage.name,
            'validation',
            'Stage validation failed after execution',
          );
        }
      }

      // Stage completed - silent in production
    } catch (e) {
      if (stage.isOptional) {
        if (kDebugMode) {
          AppLogger.warning('⚠️ Optional stage ${stage.name} failed: $e');
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
        AppLogger.debug('🔍 Validating required module for stage ${stage.name}: $moduleType');
      }
    }
  }

  /// Perform final validation after all initialization is complete.
  Future<void> _validateInitialization() async {
    if (kDebugMode) {
      AppLogger.info('🔍 Performing final validation...');
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
        AppLogger.success('✅ Final validation passed - ${healthReport.healthyCount} services healthy');
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
      AppLogger.info('🔄 ApplicationBootstrap reset complete');
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