import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

/// Simple mock ViewModel for testing widgets without full interface implementation
class MockViewModel extends Mock implements ChangeNotifier {
  final List<VoidCallback> _listeners = [];
  bool _isDisposed = false;

  // Common properties for all ViewModels
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDisposed => _isDisposed;

  @override
  void addListener(VoidCallback listener) {
    if (!_isDisposed) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      for (final listener in List.from(_listeners)) {
        listener();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  // Helper methods for testing
  void setLoadingState(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorState(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}

/// Factory for creating simple mock ViewModels for widget testing
class SimpleMockFactory {
  /// Create a generic mock ViewModel
  static MockViewModel createMockViewModel({
    bool isLoading = false,
    String? errorMessage,
  }) {
    final mock = MockViewModel();
    mock.setLoadingState(isLoading);
    mock.setErrorState(errorMessage);
    return mock;
  }
}
