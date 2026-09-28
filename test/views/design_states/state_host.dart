/// P8-U01: what one host needs to reach one state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_harness.dart';

/// The pumped host's context: the shared services and the mode.
class HostContext {
  HostContext(this.env, this.mode);

  final StateEnvironment env;
  final Brightness mode;

  /// Disposers for view models and controllers the host created.
  final List<void Function()> disposers = [];
}

/// How to reach one row's state.
///
/// [build] makes the home widget after the shared services are up. [reach]
/// drives the pumped host into the state (a tap, a stream event, a pending
/// call). [online] sets the offline fake before anything is built. The
/// conflict rows name the two rows that must both survive the union.
class StateHost {
  const StateHost({
    required this.build,
    this.reach,
    this.online = true,
    this.conflictItems,
    this.landscape = false,
  });

  final Future<Widget> Function(HostContext ctx) build;
  final Future<void> Function(WidgetTester tester, HostContext ctx)? reach;
  final bool online;
  final ({String local, String remote})? conflictItems;

  /// Pumped with width and height swapped: cooking mode forces landscape on
  /// a phone (cookingForcesLandscape, lib/views/cooking_mode_view.dart;
  /// testmatris.md:64 "Landskap: endast matlagningsläge och video").
  final bool landscape;
}
