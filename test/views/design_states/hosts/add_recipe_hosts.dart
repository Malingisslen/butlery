/// Hosts for the two ways into a new recipe (design/skiss-mot-app 38 and 39).
/// They are not among the 53 state rows; the sketch-against-app images read
/// them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/views/quick_capture_view.dart';

import '../../../infrastructure/factories/mock_factory.dart';
import '../state_host.dart';

/// Snabbspara as the sketch draws it: the title field and the meal types.
final StateHost quickCaptureHost = StateHost(
  build: (ctx) async =>
      QuickCaptureView(recipeService: MockFactory.createUnifiedRecipeService()),
);

/// Lägg till recept: the sheet the plus opens, over a blank page.
final StateHost addSheetHost = StateHost(
  build: (ctx) async => const Scaffold(body: SizedBox.expand()),
  reach: (tester, ctx) async {
    final context = tester.element(find.byType(Scaffold));
    unawaited(showButleryAddSheet(context));
    await tester.pumpAndSettle();
  },
);
