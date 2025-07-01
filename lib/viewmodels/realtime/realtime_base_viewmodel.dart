import 'package:flutter/foundation.dart';

/// Base class for realtime view models that simply proxies updates from
/// an underlying [ChangeNotifier] service to listeners.
abstract class RealtimeBaseViewModel<T extends ChangeNotifier>
    extends ChangeNotifier {
  @protected
  final T service;

  RealtimeBaseViewModel(this.service) {
    service.addListener(_onServiceChanged);
  }

  @protected
  void onServiceChanged() {}

  void _onServiceChanged() {
    onServiceChanged();
    notifyListeners();
  }

  @override
  void dispose() {
    service.removeListener(_onServiceChanged);
    super.dispose();
  }
}
