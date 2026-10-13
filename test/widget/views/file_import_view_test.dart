/// Intent: the upload card lists the required and optional columns without
/// overflowing a 360 px phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/views/file_import_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    GetIt.instance.registerSingleton<ImportManager>(MockImportManager());
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  testWidgets('the column list fits a 360 px phone with no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const FileImportView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
