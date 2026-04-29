// BUT-697 chunk-6: Semantics coverage for the chunk-6 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// `collaborative_status_widgets.banner` requires Provider scaffolding
// for the participants-list child; we test the simpler permissions
// banner + emoji picker + image-picker source option here. The chunk-8
// unwrapped-files audit catches any regression on the wider file set.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/widgets/messaging/image_picker_dialog.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_permissions_widgets.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 chunk-6 widget Semantics labels', () {
    testWidgets(
        'collaborative_permissions_widgets.permissionsBanner — exposes permission label',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (ctx) => CollaborativePermissionsWidgets.permissionsBanner(
              context: ctx,
              editMode: EditMode.collaborative,
              onTap: () {},
            ),
          ),
        ),
      );

      // Prefix matcher because the description text suffix is locale-driven.
      expect(
        find.bySemanticsLabel(RegExp(r'^Behörighet: ')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
        'group_dialog_components.EmojiSelector — emoji exposes select label',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Material(
            child: SizedBox(
              width: 400,
              height: 200,
              child: EmojiSelector(
                selectedEmoji: GroupEmojiConstants.availableEmojis.first,
                onEmojiSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // The first emoji is the selected one and exposes the select label.
      expect(
        find.bySemanticsLabel(RegExp(r'^Välj .+ som ikon')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets(
        'image_picker_dialog._SourceOption — uses passed label as Semantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const Material(child: ImagePickerDialog()),
        ),
      );

      // Both source options surface their visible Swedish labels.
      expect(
        find.bySemanticsLabel(RegExp(r'^Ta foto')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Välj från galleri')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
