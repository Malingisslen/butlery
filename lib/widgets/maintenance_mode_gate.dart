/// BUT-670: gate widget that swaps the app UI for [MaintenanceModeBlocker]
/// when Remote Config flips `app_maintenance_mode` to `true`.
///
/// Lives near the top of the widget tree (inside `MaterialApp.builder`) so
/// the blocker replaces every route — users can't navigate around it.
///
/// State sources:
///   - Initial read: `FeatureFlagService.isEnabled('app_maintenance_mode')`
///     — uses the in-memory Remote Config value (defaults applied on first
///     run, real values after `fetchAndActivate`).
///   - Live updates: `FeatureFlagService.addOnConfigUpdatedListener` so a
///     mid-session flip propagates without a cold restart.
///
/// Analytics: `AnalyticsEvents.maintenanceModeShown` fires once per session
/// the first time the blocker appears. Suppressed thereafter (using a
/// session-scoped flag) to avoid event spam if the user retries repeatedly.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/widgets/maintenance_mode_blocker.dart';

class MaintenanceModeGate extends StatefulWidget {
  /// The normal app subtree, shown when maintenance mode is OFF.
  final Widget child;

  /// Optional override for the FeatureFlagService — used by widget tests
  /// to inject a stub. Production code should leave this null and rely on
  /// the ServiceLocator default.
  final FeatureFlagService? featureFlagServiceOverride;

  const MaintenanceModeGate({
    super.key,
    required this.child,
    this.featureFlagServiceOverride,
  });

  @override
  State<MaintenanceModeGate> createState() => _MaintenanceModeGateState();
}

class _MaintenanceModeGateState extends State<MaintenanceModeGate> {
  FeatureFlagService? _flags;
  bool _maintenanceMode = false;
  String _message = '';
  bool _hasLoggedSessionShown = false;

  @override
  void initState() {
    super.initState();
    _flags = widget.featureFlagServiceOverride ??
        ServiceLocator.tryGet<FeatureFlagService>();
    _evaluateFlag();
    _flags?.addOnConfigUpdatedListener(_onConfigUpdated);
  }

  void _evaluateFlag() {
    final flags = _flags;
    if (flags == null) {
      _maintenanceMode = false;
      _message = '';
      return;
    }
    _maintenanceMode = flags.isEnabled(FeatureFlags.appMaintenanceMode);
    _message = flags.getString(FeatureFlags.appMaintenanceMessageSv);
    if (_maintenanceMode && !_hasLoggedSessionShown) {
      _hasLoggedSessionShown = true;
      AnalyticsService.tryLog(AnalyticsEvents.maintenanceModeShown);
    }
  }

  void _onConfigUpdated() {
    if (!mounted) return;
    setState(_evaluateFlag);
  }

  Future<void> _onRetry() async {
    final flags = _flags;
    if (flags == null) return;
    await flags.refresh();
    if (!mounted) return;
    setState(_evaluateFlag);
  }

  @override
  Widget build(BuildContext context) {
    if (_maintenanceMode) {
      return MaintenanceModeBlocker(message: _message, onRetry: _onRetry);
    }
    return widget.child;
  }
}
