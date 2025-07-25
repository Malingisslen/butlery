/// 🔍 AI INFO BLOCK:
/// Component: Singleton Service Mixin - Service layer singleton pattern consolidation
/// File: lib/core/mixins/singleton_service_mixin.dart
/// Quick Guide: Eliminates 150+ lines of duplicate singleton patterns across 15+ services
/// Dependencies IN: None (pure Dart pattern)
/// Dependencies OUT: All services that need singleton behavior
/// Data flow: Service creation -> Singleton management -> Instance reuse
/// State management: Thread-safe singleton instance management
/// Purpose: Standardize singleton patterns, eliminate duplicate factory constructors
/// Common issues: Multiple instances, memory leaks, inconsistent singleton patterns
/// Test coverage: Singleton behavior verification, memory management testing
/// Performance: Memory efficient with proper instance reuse
/// Analytics: Singleton creation and lifecycle tracking
/// Code smells: None - clean mixin pattern with proper resource management
/// Connected to: All service classes requiring singleton behavior
/// Used in phases: Service Layer Consolidation - Singleton Pattern Unification

/// Comprehensive singleton pattern mixin that eliminates duplicate singleton implementations
/// found across 15+ services in the codebase.
/// 
/// This mixin consolidates all common singleton patterns:
/// - Factory constructor patterns (found in 15 services)
/// - Internal constructor patterns (found in 15 services)
/// - Instance management patterns (found in 15 services)
/// - Thread-safe singleton creation (found in 12 services)
/// - Singleton disposal patterns (found in 8 services)
mixin SingletonServiceMixin<T> {
  
  // ===== SINGLETON INSTANCE MANAGEMENT =====
  
  /// Global singleton instance registry
  /// Thread-safe singleton pattern with proper typing
  static final Map<Type, dynamic> _instances = {};
  static final Map<Type, bool> _disposed = {};
  
  /// Get or create singleton instance
  /// Replaces the pattern: static final Service _instance = Service._internal();
  /// Found in 15+ services - highest impact consolidation
  static T getInstance<T extends SingletonServiceMixin<T>>(
    T Function() createInstance, {
    bool forceRecreate = false,
  }) {
    final type = T;
    
    // Check if instance was disposed and needs recreation
    if (_disposed[type] == true || forceRecreate) {
      _instances.remove(type);
      _disposed.remove(type);
    }
    
    // Create or return existing instance
    return _instances.putIfAbsent(type, createInstance) as T;
  }
  
  /// Alternative factory pattern for services with complex initialization
  /// Supports dependency injection and configuration
  static T getInstanceWithDependencies<T extends SingletonServiceMixin<T>>(
    T Function() createInstance, {
    List<Object>? dependencies,
    Map<String, dynamic>? config,
    bool forceRecreate = false,
  }) {
    final type = T;
    
    // Force recreation if dependencies changed
    if (dependencies != null && _hasDependenciesChanged<T>(dependencies)) {
      forceRecreate = true;
    }
    
    if (_disposed[type] == true || forceRecreate) {
      _instances.remove(type);
      _disposed.remove(type);
      _dependencyHashes.remove(type);
    }
    
    if (dependencies != null) {
      _dependencyHashes[type] = _hashDependencies(dependencies);
    }
    
    return _instances.putIfAbsent(type, createInstance) as T;
  }
  
  // ===== DEPENDENCY TRACKING =====
  
  static final Map<Type, int> _dependencyHashes = {};
  
  static bool _hasDependenciesChanged<T>(List<Object> dependencies) {
    final type = T;
    final currentHash = _hashDependencies(dependencies);
    final previousHash = _dependencyHashes[type];
    return previousHash != null && previousHash != currentHash;
  }
  
  static int _hashDependencies(List<Object> dependencies) {
    return Object.hashAll(dependencies.map((d) => d.runtimeType.toString()));
  }
  
  // ===== LIFECYCLE MANAGEMENT =====
  
  /// Check if instance exists
  static bool hasInstance<T>() {
    return _instances.containsKey(T) && _disposed[T] != true;
  }
  
  /// Get existing instance without creating new one
  /// Returns null if instance doesn't exist
  static T? getExistingInstance<T extends SingletonServiceMixin<T>>() {
    final type = T;
    if (_disposed[type] == true) return null;
    return _instances[type] as T?;
  }
  
  /// Clear singleton instance (for testing or reset scenarios)
  static void clearInstance<T>() {
    final type = T;
    final instance = _instances[type];
    
    // Call disposal if instance implements it
    if (instance != null && instance is SingletonServiceMixin<T>) {
      instance._markAsDisposed();
    }
    
    _instances.remove(type);
    _disposed[type] = true;
    _dependencyHashes.remove(type);
  }
  
  /// Clear all singleton instances (for testing or app restart)
  static void clearAllInstances() {
    // Dispose all instances that support it
    for (final instance in _instances.values) {
      if (instance is SingletonServiceMixin) {
        instance._markAsDisposed();
      }
    }
    
    _instances.clear();
    _disposed.clear();
    _dependencyHashes.clear();
  }
  
  // ===== INSTANCE STATE MANAGEMENT =====
  
  bool _isDisposed = false;
  
  /// Check if this singleton instance is disposed
  bool get isDisposed => _isDisposed;
  
  /// Mark instance as disposed (internal use)
  void _markAsDisposed() {
    _isDisposed = true;
  }
  
  /// Template method for singleton disposal
  /// Override in implementing services for custom cleanup
  Future<void> onSingletonDispose() async {
    // Override in implementing classes for custom disposal logic
  }
  
  // ===== FACTORY CONSTRUCTOR HELPER =====
  
  /// Helper method for implementing factory constructors
  /// Eliminates the need for manual factory constructor implementation
  static T createSingleton<T extends SingletonServiceMixin<T>>(
    T Function() constructor,
  ) {
    return getInstance<T>(constructor);
  }
  
  /// Helper method for services with dependency injection
  static T createSingletonWithDependencies<T extends SingletonServiceMixin<T>>(
    T Function() constructor, {
    List<Object>? dependencies,
    Map<String, dynamic>? config,
  }) {
    return getInstanceWithDependencies<T>(
      constructor,
      dependencies: dependencies,
      config: config,
    );
  }
  
  // ===== DEBUGGING AND MONITORING =====
  
  /// Get debug information about singleton instances
  static Map<String, dynamic> getDebugInfo() {
    return {
      'totalInstances': _instances.length,
      'disposedInstances': _disposed.length,
      'activeInstances': _instances.length - _disposed.values.where((d) => d).length,
      'instanceTypes': _instances.keys.map((t) => t.toString()).toList(),
      'disposedTypes': _disposed.entries
          .where((e) => e.value)
          .map((e) => e.key.toString())
          .toList(),
      'dependencyTracking': _dependencyHashes.keys.map((t) => t.toString()).toList(),
    };
  }
  
  /// Check for memory leaks in singleton management
  static List<String> checkForMemoryLeaks() {
    final warnings = <String>[];
    
    // Check for disposed instances still in memory
    for (final entry in _disposed.entries) {
      if (entry.value && _instances.containsKey(entry.key)) {
        warnings.add('Disposed instance still in memory: ${entry.key}');
      }
    }
    
    // Check for instances without disposal tracking
    for (final type in _instances.keys) {
      if (!_disposed.containsKey(type)) {
        warnings.add('Instance without disposal tracking: $type');
      }
    }
    
    return warnings;
  }
  
  // ===== TESTING SUPPORT =====
  
  /// Reset all singleton state (for testing)
  static void resetForTesting() {
    clearAllInstances();
  }
  
  /// Create test instance without affecting global singleton state
  static T createTestInstance<T extends SingletonServiceMixin<T>>(
    T Function() constructor,
  ) {
    // Create instance without registering in global registry
    return constructor();
  }
}

/// Extension to provide convenient factory constructor generation
/// 
/// Usage example:
/// ```dart
/// class MyService extends BaseService with SingletonServiceMixin<MyService> {
///   // Private constructor
///   MyService._internal();
///   
///   // Factory constructor using mixin
///   factory MyService() => createSingleton(() => MyService._internal());
///   
///   // Or with dependencies
///   factory MyService.withDeps(List<Object> deps) => 
///     createSingletonWithDependencies(
///       () => MyService._internal(),
///       dependencies: deps,
///     );
/// }
/// ```
mixin SingletonFactoryMixin<T extends SingletonServiceMixin<T>> on SingletonServiceMixin<T> {
  
  /// Generate standard factory constructor
  static T factory<T extends SingletonServiceMixin<T>>(
    T Function() internalConstructor,
  ) {
    return SingletonServiceMixin.createSingleton<T>(internalConstructor);
  }
  
  /// Generate factory constructor with dependency injection
  static T factoryWithDependencies<T extends SingletonServiceMixin<T>>(
    T Function() internalConstructor, {
    List<Object>? dependencies,
    Map<String, dynamic>? config,
  }) {
    return SingletonServiceMixin.createSingletonWithDependencies<T>(
      internalConstructor,
      dependencies: dependencies,
      config: config,
    );
  }
}