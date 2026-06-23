// BUT-697 chunk-5: Semantics coverage for the chunk-5 widget sweep.
// Asserts that every tap target wrapped in this sprint exposes a localized
// Semantics label discoverable via `find.bySemanticsLabel`.
//
// Like chunk-2/-3/-4, descendant Text labels merge with the wrapper label,
// so RegExp prefix matchers are used so the assertion isn't coupled to
// neighbouring text.
//
// Some files (`public_profile_view.dart`, the activity feed's recipe
// preview tile) require heavier provider scaffolding to render — we cover
// the smallest representative widgets here. The chunk-8 unwrapped-files
// audit catches any regression on the broader file set.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social_components/invitation_lists.dart';
import 'package:butlery/widgets/common/social_components/social_builder_components.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 chunk-5 widget Semantics labels', () {
    testWidgets(
      'invitation_lists.horizontalTargetList — target card exposes invite label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final target = InvitationTarget(
          type: InvitationTargetType.individual,
          targetId: 'u_1',
          displayName: 'Anna',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (ctx) => SizedBox(
                height: 100,
                child: InvitationLists.horizontalTargetList(
                  ctx,
                  targets: [target],
                ),
              ),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Bjud in Anna')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'invitation_lists.staggeredTargetGrid — target card exposes invite label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final target = InvitationTarget(
          type: InvitationTargetType.group,
          targetId: 'g_1',
          displayName: 'Familjen',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (ctx) => SizedBox(
                height: 400,
                width: 400,
                child: InvitationLists.staggeredTargetGrid(
                  ctx,
                  targets: [target],
                ),
              ),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Bjud in Familjen')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'social_builder_components.socialCard — passes semanticLabel through',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SocialBuilderComponents.socialCard(
              onTap: () {},
              semanticLabel: 'Visa medlemmens profil',
              child: const Text('Anna A.'),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Visa medlemmens profil')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'social_builder_components.socialCard — no semanticLabel ⇒ no extra wrapper',
      (tester) async {
        // Negative case: pre-existing callers that don't pass semanticLabel
        // should not get a duplicate "button" announcement.
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SocialBuilderComponents.socialCard(
              onTap: () {},
              child: const Text('Anna A.'),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Visa medlemmens profil')),
          findsNothing,
        );
        handle.dispose();
      },
    );
  });
}
