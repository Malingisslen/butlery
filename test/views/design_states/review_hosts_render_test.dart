/// Every view the screen register compares with a sketch frame must stay
/// renderable, or its sketch-against-app picture cannot be redrawn. This
/// pumps each review host once in light mode and fails on a framework error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts/review_hosts.dart';
import 'state_harness.dart';
import 'state_runner.dart';

void main() {
  for (final entry in reviewHosts.entries) {
    testWidgets('${entry.key} builds without a framework error', (
      tester,
    ) async {
      final row = StateRow(
        view: entry.key,
        state: 'DEFAULT',
        drawing: '-',
        evidence: '-',
        host: '-',
        hostFile: '-',
        hostNote: null,
        block288Category: '-',
        ownerNow: null,
      );
      final run = await pumpState(
        tester,
        row,
        Brightness.light,
        host: entry.value,
      );
      await finishState(tester, run);
      expect(run.capture.exceptions, isEmpty);
    });
  }
}
