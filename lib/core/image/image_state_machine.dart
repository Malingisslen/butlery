/// State machine for image upload lifecycle management
///
/// This replaces the complex manual state management in RecipeImageManager
/// with a clean state machine pattern that eliminates dual-mode complexity
/// and provides centralized state transition logic.
///
/// **Key Benefits:**
/// - Single source of truth for image state
/// - Declarative state transitions  
/// - Unified display and persistence models
/// - Centralized error handling
/// - Simplified upload workflow

// lib/core/image/image_state_machine.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Events that can trigger state transitions
abstract class ImageEvent {
  const ImageEvent();
}

class StartUploadEvent extends ImageEvent {
  final File file;
  const StartUploadEvent(this.file);
}

class UploadProgressEvent extends ImageEvent {
  final double progress;
  const UploadProgressEvent(this.progress);
}

class UploadCompletedEvent extends ImageEvent {
  final String url;
  const UploadCompletedEvent(this.url);
}

class UploadFailedEvent extends ImageEvent {
  final String error;
  const UploadFailedEvent(this.error);
}

class RetryUploadEvent extends ImageEvent {
  const RetryUploadEvent();
}

class CancelUploadEvent extends ImageEvent {
  const CancelUploadEvent();
}

/// Unified image state - eliminates dual-mode complexity
abstract class ImageState {
  const ImageState();
  
  /// Display path for UI (file path or URL)
  String get displayPath;
  
  /// Persistent URL for database storage (null if not uploaded)
  String? get persistentUrl;
  
  /// Progress indicator (0.0 to 1.0)
  double get progress;
  
  /// Error message if applicable
  String? get errorMessage;
  
  /// State transition handler
  ImageState handle(ImageEvent event);
  
  /// Check if event can be handled in this state
  bool canHandle(ImageEvent event);
  
  // State type checks - replace complex manual checking
  bool get isPending => this is PendingImageState;
  bool get isUploading => this is UploadingImageState;
  bool get isCompleted => this is CompletedImageState;
  bool get isFailed => this is FailedImageState;
  
  // Computed properties
  bool get isDisplayable => displayPath.isNotEmpty;
  bool get isPersistable => persistentUrl != null && isCompleted;
  bool get isRetryable => isFailed;
  bool get isCancellable => isUploading || isPending;
}

/// Initial state - image selected but not yet uploaded
class PendingImageState extends ImageState {
  final File _file;
  
  const PendingImageState(this._file);
  
  @override
  String get displayPath => _file.path;
  
  @override
  String? get persistentUrl => null;
  
  @override
  double get progress => 0.0;
  
  @override
  String? get errorMessage => null;
  
  @override
  ImageState handle(ImageEvent event) {
    switch (event) {
      case StartUploadEvent():
        AppLogger.debug('Image transition: Pending → Uploading');
        return UploadingImageState(_file);
      case CancelUploadEvent():
        AppLogger.debug('Image transition: Pending → Cancelled');
        return FailedImageState(_file, 'Upload cancelled by user');
      default:
        AppLogger.warning('Invalid event ${event.runtimeType} for PendingImageState');
        return this;
    }
  }
  
  @override
  bool canHandle(ImageEvent event) {
    return event is StartUploadEvent || event is CancelUploadEvent;
  }
}

/// Upload in progress state
class UploadingImageState extends ImageState {
  final File _file;
  final double _progress;
  
  const UploadingImageState(this._file, [this._progress = 0.0]);
  
  @override
  String get displayPath => _file.path;
  
  @override
  String? get persistentUrl => null;
  
  @override
  double get progress => _progress;
  
  @override
  String? get errorMessage => null;
  
  @override
  ImageState handle(ImageEvent event) {
    switch (event) {
      case UploadProgressEvent(:final progress):
        if (progress != _progress) {
          return UploadingImageState(_file, progress);
        }
        return this;
      case UploadCompletedEvent(:final url):
        AppLogger.debug('Image transition: Uploading → Completed');
        return CompletedImageState(url);
      case UploadFailedEvent(:final error):
        AppLogger.debug('Image transition: Uploading → Failed');
        return FailedImageState(_file, error);
      case CancelUploadEvent():
        AppLogger.debug('Image transition: Uploading → Cancelled');
        return FailedImageState(_file, 'Upload cancelled by user');
      default:
        AppLogger.warning('Invalid event ${event.runtimeType} for UploadingImageState');
        return this;
    }
  }
  
  @override
  bool canHandle(ImageEvent event) {
    return event is UploadProgressEvent || 
           event is UploadCompletedEvent || 
           event is UploadFailedEvent || 
           event is CancelUploadEvent;
  }
}

/// Upload completed successfully
class CompletedImageState extends ImageState {
  final String _url;
  
  const CompletedImageState(this._url);
  
  @override
  String get displayPath => _url;
  
  @override
  String? get persistentUrl => _url;
  
  @override
  double get progress => 1.0;
  
  @override
  String? get errorMessage => null;
  
  @override
  ImageState handle(ImageEvent event) {
    // Completed state is terminal - no valid transitions
    AppLogger.warning('Invalid event ${event.runtimeType} for CompletedImageState');
    return this;
  }
  
  @override
  bool canHandle(ImageEvent event) {
    return false; // Terminal state
  }
}

/// Upload failed state
class FailedImageState extends ImageState {
  final File? _file;
  final String _error;
  
  const FailedImageState(this._file, this._error);
  
  @override
  String get displayPath => _file?.path ?? '';
  
  @override
  String? get persistentUrl => null;
  
  @override
  double get progress => 0.0;
  
  @override
  String? get errorMessage => _error;
  
  @override
  ImageState handle(ImageEvent event) {
    switch (event) {
      case RetryUploadEvent():
        if (_file != null) {
          AppLogger.debug('Image transition: Failed → Pending (retry)');
          // ignore: unnecessary_non_null_assertion
          return PendingImageState(_file!);
        }
        AppLogger.warning('Cannot retry upload - no source file');
        return this;
      default:
        AppLogger.warning('Invalid event ${event.runtimeType} for FailedImageState');
        return this;
    }
  }
  
  @override
  bool canHandle(ImageEvent event) {
    return event is RetryUploadEvent && _file != null;
  }
}

/// State machine for individual image upload lifecycle
class ImageStateMachine extends ChangeNotifier {
  ImageState _currentState;
  final String _imageId;
  
  ImageStateMachine({
    required String imageId,
    required ImageState initialState,
  }) : _imageId = imageId,
       _currentState = initialState;
  
  /// Current state accessor
  ImageState get currentState => _currentState;
  
  /// Image identifier
  String get imageId => _imageId;
  
  /// Trigger state transition
  void transition(ImageEvent event) {
    if (!_currentState.canHandle(event)) {
      AppLogger.warning('State machine $_imageId cannot handle ${event.runtimeType} in state ${_currentState.runtimeType}');
      return;
    }
    
    final newState = _currentState.handle(event);
    if (newState != _currentState) {
      _currentState = newState;
      AppLogger.debug('State machine $_imageId transitioned to ${_currentState.runtimeType}');
      notifyListeners();
    }
  }
  
  /// Check if event can be handled
  bool canHandle(ImageEvent event) => _currentState.canHandle(event);
  
  /// Convenience getters that delegate to state
  String get displayPath => _currentState.displayPath;
  String? get persistentUrl => _currentState.persistentUrl;
  double get progress => _currentState.progress;
  String? get errorMessage => _currentState.errorMessage;
  
  bool get isPending => _currentState.isPending;
  bool get isUploading => _currentState.isUploading;
  bool get isCompleted => _currentState.isCompleted;
  bool get isFailed => _currentState.isFailed;
  
  bool get isDisplayable => _currentState.isDisplayable;
  bool get isPersistable => _currentState.isPersistable;
  bool get isRetryable => _currentState.isRetryable;
  bool get isCancellable => _currentState.isCancellable;
}

/// Collection state aggregator - replaces complex manual state checking
class ImageCollectionState extends ChangeNotifier {
  final Map<String, ImageStateMachine> _machines = {};
  
  /// Add image state machine
  void addImage(String imageId, ImageStateMachine machine) {
    _machines[imageId] = machine;
    machine.addListener(_onImageStateChanged);
    notifyListeners();
  }
  
  /// Remove image state machine
  void removeImage(String imageId) {
    final machine = _machines.remove(imageId);
    machine?.removeListener(_onImageStateChanged);
    notifyListeners();
  }
  
  /// Get specific image state machine
  ImageStateMachine? getImage(String imageId) => _machines[imageId];
  
  /// Get all image state machines
  List<ImageStateMachine> get allImages => _machines.values.toList();
  
  /// Computed state aggregations - replace manual checking
  List<ImageStateMachine> get pendingImages => _machines.values.where((m) => m.isPending).toList();
  List<ImageStateMachine> get uploadingImages => _machines.values.where((m) => m.isUploading).toList();
  List<ImageStateMachine> get completedImages => _machines.values.where((m) => m.isCompleted).toList();
  List<ImageStateMachine> get failedImages => _machines.values.where((m) => m.isFailed).toList();
  
  /// UI display paths (combines file paths and URLs automatically)
  List<String> get displayPaths => _machines.values.where((m) => m.isDisplayable).map((m) => m.displayPath).toList();
  
  /// Persistent URLs for database storage (only completed uploads)
  List<String> get persistentUrls => _machines.values
    .where((m) => m.isPersistable)
    // ignore: unnecessary_non_null_assertion
    .map((m) => m.persistentUrl!)
    .toList();
  
  /// Safety checks - replace complex manual logic
  bool get isSafeToSave => _machines.values.every((m) => m.isCompleted);
  bool get hasUploading => _machines.values.any((m) => m.isUploading);
  bool get hasFailed => _machines.values.any((m) => m.isFailed);
  bool get hasPending => _machines.values.any((m) => m.isPending);
  
  /// Progress aggregation
  double get overallProgress {
    if (_machines.isEmpty) return 1.0;
    final totalProgress = _machines.values.fold(0.0, (sum, machine) => sum + machine.progress);
    return totalProgress / _machines.length;
  }
  
  /// Retry all failed uploads
  void retryFailed() {
    for (final machine in failedImages) {
      if (machine.isRetryable) {
        machine.transition(const RetryUploadEvent());
      }
    }
  }
  
  /// Cancel all active uploads
  void cancelAll() {
    for (final machine in _machines.values) {
      if (machine.isCancellable) {
        machine.transition(const CancelUploadEvent());
      }
    }
  }
  
  /// Clear all images
  void clear() {
    for (final machine in _machines.values) {
      machine.removeListener(_onImageStateChanged);
    }
    _machines.clear();
    notifyListeners();
  }
  
  void _onImageStateChanged() {
    notifyListeners();
  }
  
  /// Statistics
  Map<String, int> get statistics => {
    'total': _machines.length,
    'pending': pendingImages.length,
    'uploading': uploadingImages.length,
    'completed': completedImages.length,
    'failed': failedImages.length,
  };
  
  @override
  void dispose() {
    clear();
    super.dispose();
  }
}