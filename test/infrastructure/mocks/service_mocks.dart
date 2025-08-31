/// Service and utility mocks that extend production_mocks.dart
/// 
/// These mocks implement service interfaces not covered in production_mocks.dart
/// All mocks follow the pattern: NO concrete implementations, only configuration
/// state and getters. Methods are handled by Mock for proper stubbing.
library;

import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

// Production imports for proper mocking
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/recipe_unified.dart';

// Service interfaces - add as needed when interfaces are available
// For now, these are placeholder mocks without interfaces

/// Mock for services and utilities not yet having interfaces
/// These will be updated to implement proper interfaces when available

class MockMessagesRepository extends Mock {
  // Different from MockMessagingRepository - for message content vs messaging system
}

// MockUnifiedShoppingService moved to production_mocks.dart with full implementation

class MockMessagingService extends Mock implements MessagingService {
  // Configuration state
  final Map<String, Conversation> _conversations = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, StreamController<List<Message>>> _messageStreamControllers = {};
  
  // Configure conversation for testing
  void setConversation(String conversationId, Conversation conversation) {
    _conversations[conversationId] = conversation;
  }
  
  // Configure messages for testing
  void setMessages(String conversationId, List<Message> messages) {
    _messages[conversationId] = messages;
    // Update stream if it exists
    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!.add(messages);
    }
  }
  
  // Create stream controller for conversation messages
  StreamController<List<Message>> createMessageStream(String conversationId) {
    final controller = StreamController<List<Message>>.broadcast();
    _messageStreamControllers[conversationId] = controller;
    // Add initial messages if any
    if (_messages.containsKey(conversationId)) {
      controller.add(_messages[conversationId]!);
    }
    return controller;
  }
  
  // Clean up stream controllers
  void disposeStreams() {
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();
  }
  
  // Reset mock state
  void resetState() {
    _conversations.clear();
    _messages.clear();
    disposeStreams();
  }
}

class MockMenuService extends Mock with ChangeNotifier implements MenuService {
  Map<String, List<Recipe>>? _generateMenuResult;
  String? _lastGeneratePrompt;
  List<Recipe>? _lastGenerateRecipes;
  bool _shouldThrowError = false;

  /// Configure the result for generateMenuFromPrompt
  void setGenerateMenuResult(Map<String, List<Recipe>> result) {
    _generateMenuResult = result;
  }

  /// Configure mock to throw error on next operation
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  /// Get the last prompt used in generateMenuFromPrompt
  String? get lastGeneratePrompt => _lastGeneratePrompt;

  /// Get the last recipes list used in generateMenuFromPrompt
  List<Recipe>? get lastGenerateRecipes => _lastGenerateRecipes;

  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes,
  ) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    _lastGeneratePrompt = input;
    _lastGenerateRecipes = allRecipes;

    return _generateMenuResult ?? <String, List<Recipe>>{};
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }
}

class MockSearchService extends Mock implements SearchService {}

class MockRecipeDiscoveryService extends Mock implements RecipeDiscoveryService {
  // Configuration state
  List<Recipe> _trendingRecipes = [];
  List<Recipe> _searchResults = [];
  List<Recipe> _recentlySharedRecipes = [];
  bool _shouldThrowError = false;

  /// Configure trending recipes result
  void setTrendingRecipes(List<Recipe> recipes) {
    _trendingRecipes = recipes;
  }

  /// Configure search results
  void setSearchResults(List<Recipe> results) {
    _searchResults = results;
  }

  /// Configure recently shared recipes result
  void setRecentlySharedRecipes(List<Recipe> recipes) {
    _recentlySharedRecipes = recipes;
  }

  /// Configure mock to throw error on next operation
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  /// Mock implementation of getTrendingRecipes
  @override
  Future<List<Recipe>> getTrendingRecipes({
    int limit = 20,
    Duration? timeWindow,
    List<String>? categoryFilter,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    var result = List<Recipe>.from(_trendingRecipes);
    if (limit > 0 && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  /// Mock implementation of searchRecipes
  @override
  Future<List<Recipe>> searchRecipes({
    required String query,
    int limit = 20,
    List<String>? categoryFilter,
    bool includePersonal = false,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    var result = List<Recipe>.from(_searchResults);
    if (limit > 0 && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  /// Mock implementation of getRecentlySharedRecipes
  @override
  Future<List<Recipe>> getRecentlySharedRecipes({
    int limit = 20,
    Duration? timeWindow,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    var result = List<Recipe>.from(_recentlySharedRecipes);
    if (limit > 0 && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  /// Reset mock state
  void resetState() {
    _trendingRecipes.clear();
    _searchResults.clear();
    _recentlySharedRecipes.clear();
    _shouldThrowError = false;
  }
}

class MockRecommendationService extends Mock implements RecommendationService {
  // Configuration state
  List<Recommendation> _recommendations = [];
  bool _shouldThrowError = false;
  final Map<String, bool> _feedbackResults = {};

  /// Configure recommendations result
  void setRecommendations(List<Recommendation> recommendations) {
    _recommendations = recommendations;
  }

  /// Configure mock to throw error on next operation
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  /// Configure feedback operation results
  void setFeedbackResult(String recommendationId, bool success) {
    _feedbackResults[recommendationId] = success;
  }

  @override
  Future<List<Recommendation>> generateRecommendations({
    required String userId,
    int limit = 10,
    List<RecommendationType>? types,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    var result = List<Recommendation>.from(_recommendations);
    if (limit > 0 && result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  @override
  Future<void> provideFeedback(String recommendationId, FeedbackType feedbackType) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    final success = _feedbackResults[recommendationId] ?? true;
    if (!success) {
      throw Exception('Feedback failed for recommendation: $recommendationId');
    }
    
    // Update the local recommendation state if it exists
    final recommendation = _recommendations.cast<Recommendation?>().firstWhere(
      (rec) => rec?.id == recommendationId,
      orElse: () => null,
    );
    
    if (recommendation != null) {
      switch (feedbackType) {
        case FeedbackType.like:
          recommendation.isLiked = true;
          recommendation.isDismissed = false;
          break;
        case FeedbackType.dismiss:
        case FeedbackType.notInterested:
          recommendation.isDismissed = true;
          recommendation.isLiked = false;
          break;
        case FeedbackType.save:
          // Save doesn't change dismissed/liked state in this mock
          break;
      }
    }
  }

  @override
  Future<void> undoDismissal(String recommendationId) async {
    if (_shouldThrowError) {
      throw Exception('Mock configured to throw error');
    }

    final recommendation = _recommendations.cast<Recommendation?>().firstWhere(
      (rec) => rec?.id == recommendationId,
      orElse: () => null,
    );
    
    if (recommendation != null) {
      recommendation.isDismissed = false;
    }
  }

  /// Reset mock state
  void resetState() {
    _recommendations.clear();
    _feedbackResults.clear();
    _shouldThrowError = false;
  }
}

// MockAnalyticsService moved to production_mocks.dart to avoid conflict

class MockStorageService extends Mock implements StorageService {
  // Storage service mock - properly implements StorageService
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