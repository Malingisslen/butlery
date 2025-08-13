/// Service and utility mocks that extend production_mocks.dart
/// 
/// These mocks implement service interfaces not covered in production_mocks.dart
/// All mocks follow the pattern: NO concrete implementations, only configuration
/// state and getters. Methods are handled by Mock for proper stubbing.
library;

import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

// Service interfaces - add as needed when interfaces are available
// For now, these are placeholder mocks without interfaces

/// Mock for services and utilities not yet having interfaces
/// These will be updated to implement proper interfaces when available

class MockMessagesRepository extends Mock {
  // Different from MockMessagingRepository - for message content vs messaging system
}

class MockUnifiedShoppingService extends Mock with ChangeNotifier {
  // Shopping service mock - will implement interface when available
}

class MockMessagingService extends Mock with ChangeNotifier {
  // Messaging service (not repository) - will implement interface when available
}

class MockMenuService extends Mock with ChangeNotifier {
  // Menu service mock - will implement interface when available
}

class MockImportManager extends Mock {
  // Import manager mock - will implement interface when available
}

class MockSearchService extends Mock with ChangeNotifier {
  // Search service mock - will implement interface when available
}

class MockRecipeDiscoveryService extends Mock with ChangeNotifier {
  // Recipe discovery service mock - will implement interface when available
}

class MockAnalyticsService extends Mock with ChangeNotifier {
  // Analytics service mock - will implement interface when available
}

class MockStorageService extends Mock {
  // Storage service mock - will implement interface when available
}

class MockDialogService extends Mock {
  // Dialog service mock - will implement interface when available
}

class MockConnectivityService extends Mock {
  // Connectivity service mock - will implement interface when available
}

// ViewModel mocks
class MockRecipeListViewModel extends Mock with ChangeNotifier {
  // Recipe list view model mock - will implement interface when available
}

class MockShoppingViewModel extends Mock with ChangeNotifier {
  // Shopping view model mock - will implement interface when available
}

class MockMenuViewModel extends Mock with ChangeNotifier {
  // Menu view model mock - will implement interface when available
}

class MockFriendsViewModel extends Mock with ChangeNotifier {
  // Friends view model mock - will implement interface when available
}

class MockProfileViewModel extends Mock with ChangeNotifier {
  // Profile view model mock - will implement interface when available
}

class MockSettingsViewModel extends Mock with ChangeNotifier {
  // Settings view model mock - will implement interface when available
}

// Utility mocks
class MockLogger extends Mock {
  // Logger mock - will implement interface when available
}

class MockErrorHandler extends Mock {
  // Error handler mock - will implement interface when available
}

class MockCacheManager extends Mock {
  // Cache manager mock - will implement interface when available
}

class MockNetworkManager extends Mock {
  // Network manager mock - will implement interface when available
}