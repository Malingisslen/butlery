/// P8-U01: the harness that pumps one of the 53 visual-only view states.
///
/// Every state is pumped the same way: the app's own theme
/// (AppTheme.lightTheme / darkTheme, lib/theme/app_theme.dart:14-17), a
/// 360 x 800 dp surface at device pixel ratio 1.0, Swedish, and fakes only at
/// the service, clock and permission edges. What the host looks like in that
/// state is left to the app; the harness never paints anything itself.
///
/// The rows come from test/fixtures/design/ux-beteende-53.json, vendored from
/// the design session's ux-beteende.json (KLASS = VISUAL_ONLY_MIGRATION) with
/// its sha256. Each row names the file the state was evidenced in (BEVIS) and
/// the widget the harness pumps (HOST). The HOST is an interpretation, made
/// here and recorded next to BEVIS, which is never rewritten.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_theme.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../widget/views/sync/fake_sync_queue_source.dart';

/// The fixture the 53 rows are read from.
const stateFixturePath = 'test/fixtures/design/ux-beteende-53.json';

/// Swedish copy, read from the generated localisations, never typed here.
final sv = AppLocalizationsSv();

/// The surface every state is pumped on unless a matrix says otherwise.
const Size stateSurface = Size(360, 800);

/// One of the 53 rows.
class StateRow {
  StateRow({
    required this.view,
    required this.state,
    required this.drawing,
    required this.evidence,
    required this.host,
    required this.hostFile,
    required this.hostNote,
    required this.block288Category,
    required this.ownerNow,
  });

  factory StateRow.fromJson(Map<String, dynamic> json) => StateRow(
    view: json['VY'] as String,
    state: json['TILLSTAND'] as String,
    drawing: json['RITNING'] as String,
    evidence: json['BEVIS'] as String,
    host: json['HOST'] as String,
    hostFile: json['HOST_FILE'] as String,
    hostNote: json['HOST_NOTE'] as String?,
    block288Category: json['BLOCK288_KATEGORI'] as String,
    ownerNow: json['AGARE_NU'] as String?,
  );

  /// The view key in block288 (e.g. "inköpslista").
  final String view;

  /// DEFAULT, LOADING, EMPTY, OFFLINE or CONFLICT.
  final String state;

  /// PRESENT or ABSENT in the drawings (ux-beteende.json RITNING).
  final String drawing;

  /// Where the state was evidenced (ux-beteende.json BEVIS), unchanged.
  final String evidence;

  /// The class the harness pumps.
  final String host;

  /// The file that declares [host].
  final String hostFile;

  /// Why the host differs from the evidence, when it does.
  final String? hostNote;

  /// fas2/block288-uxfrysning.json vytillstand KATEGORI for (view, state).
  final String block288Category;

  /// The file that owns the state today, when it moved (the Hem rows).
  final String? ownerNow;

  /// The row's identity: view and state, never its position.
  String get id => '$view::$state';

  @override
  String toString() => id;
}

/// The vendored fixture, parsed.
class StateFixture {
  StateFixture(this.json);

  factory StateFixture.load() => StateFixture(
    jsonDecode(File(stateFixturePath).readAsStringSync())
        as Map<String, dynamic>,
  );

  final Map<String, dynamic> json;

  List<StateRow> get rows => [
    for (final row in json['rows'] as List<dynamic>)
      StateRow.fromJson(row as Map<String, dynamic>),
  ];

  Map<String, dynamic> get source => json['source'] as Map<String, dynamic>;

  Map<String, dynamic> get block288 => json['block288'] as Map<String, dynamic>;
}

/// Loads the app's own family (pubspec.yaml fonts: ButlerySans 0.626).
///
/// The test font draws every glyph one em wide, about twice as wide as
/// ButlerySans, so an overflow measured in it says little about the app.
/// The pattern of test/widget/views/root_bar_title_room_test.dart:80-91.
Future<void> loadButlerySans() async {
  final loader = FontLoader('ButlerySans');
  for (final face in [
    'Regular',
    'Italic',
    'Semibold',
    'SemiboldItalic',
    'Bold',
    'BoldItalic',
  ]) {
    final bytes = File(
      'assets/fonts/ButlerySans-0.626-$face.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// The light and dark themes the app ships.
ThemeData themeFor(Brightness mode) =>
    mode == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;

/// Services every host can reach: the offline service the banner reads, the
/// queue the banner counts, and the production locator bridged onto the test
/// one (the pattern of test/views/messaging/conversations_list_view_test.dart).
class StateEnvironment {
  StateEnvironment._(this.offline, this.queue);

  final FakeOfflineService offline;
  final FakeSyncQueueSource queue;

  /// Sets up the shared services, online or not.
  static Future<StateEnvironment> setUp({required bool online}) async {
    // A host that failed half-way through a stub must not break the next.
    resetMocktailState();
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    prod.ServiceLocator.reset();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
    final offline = FakeOfflineService()..setOnline(online);
    TestServiceLocator.registerMock<OfflineService>(offline);
    // The second connectivity source some view models read
    // (UnifiedShoppingViewModel.isOnline, the import pre-check).
    final monitor = MockConnectivityMonitoringService();
    when(() => monitor.isConnectedToInternet).thenReturn(online);
    TestServiceLocator.registerMock<ConnectivityMonitoringService>(monitor);
    final queue = FakeSyncQueueSource()..online = online;
    SyncQueueSource.debugOverride = queue;
    return StateEnvironment._(offline, queue);
  }

  /// Undoes [setUp].
  Future<void> tearDown() async {
    SyncQueueSource.debugOverride = null;
    await TestServiceLocator.reset();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  }
}

/// The app shell around a host: the shipped theme for [mode], Swedish, a
/// route generator that answers every named route with a blank page, and the
/// text scale for the accessibility matrix.
Widget stateApp({
  required Brightness mode,
  required Widget home,
  double textScale = 1.0,
  GlobalKey<NavigatorState>? navigatorKey,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  debugShowCheckedModeBanner: false,
  theme: themeFor(mode),
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const Scaffold(body: SizedBox.shrink()),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

/// Everything the framework reported while a state was pumped. Overflows are
/// kept here and go no further, since the rule reads them. Any other error
/// is noted here and goes on to the test binding as usual; the runner takes
/// it back with tester.takeException so that it is judged as a finding too.
class StateCapture {
  final List<String> overflows = [];
  final List<String> exceptions = [];

  void Function(FlutterErrorDetails)? _previous;
  bool _restored = false;

  /// Gives the binding its own handler back. Called before any expect, so
  /// a failing expectation is reported as a failure, not kept as a finding.
  void restore() {
    if (_restored) return;
    _restored = true;
    FlutterError.onError = _previous;
  }
}

/// Sets the surface for one pump and restores it afterwards.
void setStateSurface(WidgetTester tester, {Size size = stateSurface}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Keeps every overflow report in [StateCapture.overflows] for the rest of
/// the test, instead of failing the test at the first one, so the rule can
/// judge them: an overflow is a finding with a row, not a crash. Every other
/// report goes on to the binding's own handler.
StateCapture captureFrameworkErrors() {
  final capture = StateCapture();
  final previous = FlutterError.onError;
  capture._previous = previous;
  FlutterError.onError = (details) {
    final overflow =
        details.library == 'rendering library' &&
        details.exception is FlutterError &&
        details.exceptionAsString().contains('overflowed by');
    if (overflow) {
      capture.overflows.add(details.exceptionAsString().split('\n').first);
      return;
    }
    capture.exceptions.add(details.exceptionAsString().split('\n').first);
    previous?.call(details);
  };
  addTearDown(capture.restore);
  return capture;
}

/// Takes back the error the binding holds, so that it is judged as a finding
/// (its first line is already in [StateCapture.exceptions]) instead of
/// failing the test on its own.
void drainExceptions(WidgetTester tester, StateCapture capture) {
  final error = tester.takeException();
  if (error != null && capture.exceptions.isEmpty) {
    capture.exceptions.add(error.toString().split('\n').first);
  }
}
