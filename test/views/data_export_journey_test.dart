/// Journey test: "Exportera mina data" (GDPR Art. 15/20) from the user's side.
///
/// The real [DataExportView] and the real [DataExportViewModel] run; only the
/// [DataExportService] (the Firestore-reading edge) is a fake. The user taps
/// export, waits, sees the finished file with its size and a "Spara fil"
/// action, and can clear it again. When the connection drops the user is told
/// the export was cut off, is offered NO partial file, and a retry produces
/// the real one.
library;

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/views/account/data_export_view.dart';

class _FakeExportService implements DataExportService {
  _FakeExportService(this._outcomes);

  final List<FutureOr<String> Function()> _outcomes;
  int calls = 0;

  @override
  Future<String> exportUserData() async => _outcomes[calls++]();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of this journey',
  );
}

final _sv = AppLocalizationsSv();
final _exportButton = find.byKey(const ValueKey('dataExport.export'));
final _saveFile = find.byKey(const ValueKey('dataExport.saveFile'));

Future<void> _pumpExportScreen(
  WidgetTester tester,
  _FakeExportService service, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The "what is included" rows do not wrap (BUT-2360); this journey reads
  // flow and copy, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);
  final viewModel = DataExportViewModel(exportService: service);
  await tester.pumpWidget(
    ChangeNotifierProvider<DataExportViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const DataExportView(),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

/// The app theme gives every FilledButton `minimumSize: Size(infinity, 48)`
/// (lib/theme/components/button_themes.dart), and the export error card puts
/// "Försök igen" in a Row, so under the REAL theme that card throws "BoxConstraints
/// forces an infinite width" in layout. The retry journey is proven with the
/// minimum width neutralised for that one button kind; drop this override
/// once the view sizes its own buttons (BUT-2360).
ThemeData _themeWithRowSafeFilledButtons() {
  final base = AppTheme.lightTheme;
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      ),
    ),
  );
}

void main() {
  testWidgets('user exports their data, sees the finished file, and can '
      'clear it again', (tester) async {
    final gate = Completer<String>();
    final service = _FakeExportService([() => gate.future]);
    await _pumpExportScreen(tester, service);

    expect(find.text(_sv.dataExportGdprDescription), findsOneWidget);
    expect(_saveFile, findsNothing, reason: 'nothing to save before exporting');

    await tester.tap(_exportButton);
    await tester.pump();
    expect(
      find.text(_sv.dataExportExporting),
      findsOneWidget,
      reason: 'the user is told the export is running',
    );
    expect(find.text(_sv.dataExportMayTakeSeconds), findsOneWidget);

    gate.complete('{"profile":{"name":"Malin"}}');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(service.calls, 1);
    expect(find.text(_sv.dataExportSuccess), findsOneWidget);
    expect(
      find.textContaining('${_sv.dataExportFileSize}: 1 KB'),
      findsOneWidget,
    );
    expect(_saveFile, findsOneWidget, reason: 'the file can now be saved');
    expect(_exportButton, findsNothing, reason: 'export is not offered twice');
    expect(find.text(_sv.dataExportMemoryNotice), findsOneWidget);

    await tester.tap(find.text(_sv.dataExportClear));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text(_sv.dataExportClearConfirmTitle), findsOneWidget);
    await tester.tap(find.text(_sv.commonClear));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      _saveFile,
      findsNothing,
      reason: 'cleared data can no longer be saved',
    );
    expect(_exportButton, findsOneWidget, reason: 'the user can export again');
  });

  testWidgets('a dropped connection offers no partial file, and retry '
      'delivers the real one', (tester) async {
    final service = _FakeExportService([
      () => throw const SocketException('connection lost'),
      () => '{"profile":{"name":"Malin"}}',
    ]);
    await _pumpExportScreen(
      tester,
      service,
      theme: _themeWithRowSafeFilledButtons(),
    );

    await tester.tap(_exportButton);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(_sv.dataExportNetworkTitle), findsOneWidget);
    expect(find.text(_sv.dataExportNoPartialFile), findsOneWidget);
    expect(_saveFile, findsNothing, reason: 'no partial file is ever offered');

    await tester.tap(find.byKey(const ValueKey('dataExport.retry')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(service.calls, 2);
    expect(find.text(_sv.dataExportNetworkTitle), findsNothing);
    expect(find.text(_sv.dataExportSuccess), findsOneWidget);
    expect(_saveFile, findsOneWidget);
  });
}
