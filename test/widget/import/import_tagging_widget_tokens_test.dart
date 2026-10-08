// BUT-2183 5j: the import and tagging widgets leave the old opacity steps.
// Status chips and notices are the mode's surface tint with no border (B83-2)
// and the matching on-colour for glyph and text; plain fills are the raised
// surface (or surface.base when the parent is already raised); borders are
// outlineVariant; inactive glyphs are textDisabled. Each test runs in both
// modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/import/input_detector.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/brand_colors.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';
import 'package:butlery/widgets/import/confidence_indicator.dart';
import 'package:butlery/widgets/import/platform_badge_widget.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/tagging/personal_tag_rule_dialog.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';
import 'package:butlery/widgets/tagging/tag_detail_header.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/builders/personal_tag_builder.dart';
import '../../infrastructure/helpers/tagging_test_helper.dart';

class _EmptyViewModel extends ChangeNotifier implements PersonalTagViewModel {
  @override
  bool get isLoading => false;

  @override
  bool get hasTags => false;

  @override
  bool get loadFailed => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Module implements DIModule {
  _Module(this.vm);

  final _EmptyViewModel vm;

  @override
  String get name => 'ImportTaggingTokensTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [PersonalTagViewModel];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<PersonalTagViewModel>(vm);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
  await tester.pump();
}

/// The nearest Container above [of] that paints a BoxDecoration.
BoxDecoration _decorationAbove(WidgetTester tester, Finder of) {
  final container = find
      .ancestor(
        of: of,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

BoxDecoration _badgeDecoration(WidgetTester tester) =>
    tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(PlatformBadgeWidget),
                matching: find.byType(Container),
              ),
            )
            .first
            .decoration!
        as BoxDecoration;

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

Color? _glyphColor(WidgetTester tester, Finder glyph) =>
    tester.widget<Icon>(glyph).color;

/// The colour of the label beside [glyph]: the first Text in the nearest Row
/// that holds the glyph.
Color? _labelColorBeside(WidgetTester tester, Finder glyph) {
  final row = find.ancestor(of: glyph, matching: find.byType(Row)).first;
  final label = find.descendant(of: row, matching: find.byType(Text)).first;
  return tester.widget<Text>(label).style?.color;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('confidence chip, $mode', () {
      testWidgets('high is the success tint, no border, onSuccessContainer', (
        tester,
      ) async {
        await _pump(tester, theme, const ConfidenceIndicator(confidence: 0.9));

        final decoration = _decorationAbove(tester, find.text('90%'));
        expect(decoration.color, modeColors.surfaceTintSuccess);
        expect(decoration.border, isNull);
        expect(
          _textColor(tester, find.text('90%')),
          modeColors.onSuccessContainer,
        );
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.circleCheck)),
          modeColors.onSuccessContainer,
        );
      });

      testWidgets('medium is the warning tint with textWarning', (
        tester,
      ) async {
        await _pump(tester, theme, const ConfidenceIndicator(confidence: 0.7));

        final decoration = _decorationAbove(tester, find.text('70%'));
        expect(decoration.color, modeColors.surfaceTintWarning);
        expect(decoration.border, isNull);
        expect(
          _textColor(tester, find.text('70%')),
          AppModeColors.textWarning(theme.brightness),
        );
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.info)),
          AppModeColors.textWarning(theme.brightness),
        );
      });

      testWidgets('low is the danger tint with onErrorContainer', (
        tester,
      ) async {
        await _pump(tester, theme, const ConfidenceIndicator(confidence: 0.3));

        final decoration = _decorationAbove(tester, find.text('30%'));
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(_textColor(tester, find.text('30%')), cs.onErrorContainer);
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.triangleAlert)),
          cs.onErrorContainer,
        );
      });
    });

    group('platform badge, $mode', () {
      InputDetectionResult detection(Platform platform) => InputDetectionResult(
        type: InputType.url,
        platform: platform,
        input: 'https://example.com',
      );

      testWidgets('website is raised with an outlineVariant border', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          PlatformBadgeWidget(detection: detection(Platform.website)),
        );

        final badge = _badgeDecoration(tester);
        expect(badge.color, cs.surfaceContainerHighest);
        expect((badge.border! as Border).top.color, cs.outlineVariant);
      });

      testWidgets('unknown is raised with an outlineVariant border', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          PlatformBadgeWidget(detection: detection(Platform.unknown)),
        );

        final badge = _badgeDecoration(tester);
        expect(badge.color, cs.surfaceContainerHighest);
        expect((badge.border! as Border).top.color, cs.outlineVariant);
      });

      // The brand is on the glyph only: the badge is the raised fill, the
      // outlineVariant line and ink text like the rest, and the glyph is the
      // brand's own colour, TikTok taking the half of its brand that shows on
      // the mode's fill.
      final dark = theme.brightness == Brightness.dark;
      for (final (platform, glyph, brand) in [
        (Platform.youtube, Icons.play_circle_outline, BrandColors.youtube),
        (
          Platform.tiktok,
          Icons.music_note,
          dark ? BrandColors.tiktok : BrandColors.tiktokText,
        ),
        (Platform.instagram, ButleryIcons.camera, BrandColors.instagram),
      ]) {
        testWidgets('$platform is the raised fill with brand only on the '
            'glyph, and ink text that reads', (tester) async {
          await _pump(
            tester,
            theme,
            PlatformBadgeWidget(detection: detection(platform)),
          );

          final badge = _badgeDecoration(tester);
          expect(badge.color, cs.surfaceContainerHighest);
          final border = badge.border! as Border;
          expect(border.top.color, cs.outlineVariant);
          expect(border.top.width, 1);
          expect(
            tester
                .widget<ButleryIcon>(
                  find.byWidgetPredicate(
                    (w) => w is ButleryIcon && w.icon == glyph,
                  ),
                )
                .color,
            brand,
          );
          final label = tester.widget<Text>(
            find.descendant(
              of: find.byType(PlatformBadgeWidget),
              matching: find.byType(Text),
            ),
          );
          expect(label.style?.color, cs.onSurface);
          expect(
            _contrast(label.style!.color!, cs.surfaceContainerHighest),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    });

    group('plain fields and glyphs, $mode', () {
      testWidgets('the add-item field border is outlineVariant', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          AddItemField(hintText: 'Lägg till', onAdd: (_) {}),
        );

        final border =
            tester.widget<TextField>(find.byType(TextField)).decoration!.border!
                as OutlineInputBorder;
        expect(border.borderSide.color, cs.outlineVariant);
      });

      testWidgets('the empty line selector glyph is textDisabled', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          SizedBox(
            height: 300,
            child: TextLineSelector(
              lines: const [],
              selectedIndices: const {},
              onSelectionChanged: (_) {},
            ),
          ),
        );

        expect(
          _glyphColor(tester, find.byIcon(Icons.text_fields)),
          AppModeColors.textDisabled(theme.brightness),
        );
      });

      testWidgets('the tag detail avatar sits on surface inside its card', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          TagDetailHeader(
            tag: PersonalTag(
              id: 't1',
              name: 'Favoriter',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
            usageCount: 3,
          ),
        );

        expect(
          tester
              .widget<CircleAvatar>(find.byType(CircleAvatar))
              .backgroundColor,
          cs.surface,
        );
      });
    });

    group('status badges, $mode', () {
      Future<void> pumpBadge(WidgetTester tester, Widget badge) =>
          _pump(tester, theme, badge);

      testWidgets('allergen FREE is the success tint with no border', (
        tester,
      ) async {
        await pumpBadge(
          tester,
          const AllergenStatusBadge(allergen: 'gluten', status: TriState.free),
        );

        final decoration = _decorationAbove(
          tester,
          find.byIcon(ButleryIcons.circleCheck),
        );
        expect(decoration.color, modeColors.surfaceTintSuccess);
        expect(decoration.border, isNull);
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.circleCheck)),
          modeColors.onSuccessContainer,
        );
        expect(
          _labelColorBeside(tester, find.byIcon(ButleryIcons.circleCheck)),
          modeColors.onSuccessContainer,
        );
      });

      testWidgets(
        'allergen CONTAINS is the danger tint with onErrorContainer',
        (
          tester,
        ) async {
          await pumpBadge(
            tester,
            const AllergenStatusBadge(
              allergen: 'gluten',
              status: TriState.contains,
            ),
          );

          final decoration = _decorationAbove(
            tester,
            find.byIcon(ButleryIcons.triangleAlert),
          );
          expect(decoration.color, modeColors.surfaceTintDanger);
          expect(decoration.border, isNull);
          expect(
            _glyphColor(tester, find.byIcon(ButleryIcons.triangleAlert)),
            cs.onErrorContainer,
          );
          expect(
            _labelColorBeside(tester, find.byIcon(ButleryIcons.triangleAlert)),
            cs.onErrorContainer,
          );
        },
      );

      testWidgets('compact dietary CONTAINS is neutral: raised, no border', (
        tester,
      ) async {
        await pumpBadge(
          tester,
          const DietaryStatusBadge(
            diet: 'vegetarian',
            status: TriState.contains,
            compact: true,
          ),
        );

        final decoration = _decorationAbove(
          tester,
          find.byIcon(Icons.cancel_outlined),
        );
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(decoration.border, isNull);
        expect(
          _glyphColor(tester, find.byIcon(Icons.cancel_outlined)),
          cs.onSurfaceVariant,
        );
      });

      testWidgets('compact dietary FREE is the success tint', (tester) async {
        await pumpBadge(
          tester,
          const DietaryStatusBadge(
            diet: 'vegetarian',
            status: TriState.free,
            compact: true,
          ),
        );

        final decoration = _decorationAbove(
          tester,
          find.byIcon(ButleryIcons.leaf),
        );
        expect(decoration.color, modeColors.surfaceTintSuccess);
        expect(decoration.border, isNull);
      });

      testWidgets('dietary UNKNOWN is neutral: raised, onSurfaceVariant', (
        tester,
      ) async {
        await pumpBadge(
          tester,
          const DietaryStatusBadge(
            diet: 'vegetarian',
            status: TriState.unknown,
          ),
        );

        final decoration = _decorationAbove(
          tester,
          find.byIcon(ButleryIcons.info),
        );
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(decoration.border, isNull);
        expect(
          _labelColorBeside(tester, find.byIcon(ButleryIcons.info)),
          cs.onSurfaceVariant,
        );
      });
    });

    group('notices, $mode', () {
      testWidgets('the outdated-tagging notice is the warning tint with '
          'textWarning and no border', (tester) async {
        await _pump(
          tester,
          theme,
          TagResultDisplay(
            tagResult: TaggingTestHelper.createTagResult(
              generatorVersion: '0.0.1',
            ),
            onRetagRequested: () {},
          ),
        );

        final decoration = _decorationAbove(tester, find.byIcon(Icons.update));
        expect(decoration.color, modeColors.surfaceTintWarning);
        expect(decoration.border, isNull);
        expect(
          _glyphColor(tester, find.byIcon(Icons.update)),
          AppModeColors.textWarning(theme.brightness),
        );
      });

      testWidgets('the rule dialog error is the danger tint with '
          'onErrorContainer and no border', (tester) async {
        final tag = PersonalTag(
          id: 't1',
          name: 'Favoriter',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // The condition dropdowns overflow the dialog's width in a test
        // viewport; this test reads the notice, not the condition card.
        final originalHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalHandler);
        await _pump(
          tester,
          theme,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PersonalTagRuleDialog(
                  availableTags: [tag],
                  preselectedTagId: 't1',
                ),
              ),
              child: const Text('Öppna'),
            ),
          ),
        );
        await tester.tap(find.text('Öppna'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, 'Regel');
        await tester.tap(find.text('Skapa'));
        await tester.pump();

        final decoration = _decorationAbove(
          tester,
          find.byIcon(ButleryIcons.triangleAlert),
        );
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.triangleAlert)),
          cs.onErrorContainer,
        );
        expect(
          _labelColorBeside(tester, find.byIcon(ButleryIcons.triangleAlert)),
          cs.onErrorContainer,
        );
      });

      testWidgets('the rule dialog saves and closes with its busy button '
          'drawn in the row', (tester) async {
        final tag = PersonalTag(
          id: 't1',
          name: 'Favoriter',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final rule = PersonalTagRuleBuilder()
            .withTagId('t1')
            .withName('Regel')
            .withIngredientCondition('kyckling')
            .build();
        await tester.binding.setSurfaceSize(const Size(900, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final originalHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalHandler);
        Object? popped;
        await _pump(
          tester,
          theme,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await showDialog<Object?>(
                  context: context,
                  builder: (_) => PersonalTagRuleDialog(
                    availableTags: [tag],
                    existingRule: rule,
                  ),
                );
              },
              child: const Text('Öppna'),
            ),
          ),
        );
        await tester.tap(find.text('Öppna'));
        await tester.pumpAndSettle();

        // Saving pops in the same step that sets the busy style, so the
        // exit animation is what draws the busy button.
        await tester.tap(find.text('Spara'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(PersonalTagRuleDialog), findsNothing);
        expect(popped, isNotNull);
      });
    });

    group('personal tag selector, $mode', () {
      setUp(() async {
        final container = DIContainer();
        await container.reset();
        container.registerModule(_Module(_EmptyViewModel()));
        await container.initialize();
        ServiceLocator.initialize(container);
      });

      testWidgets('the empty state glyph is textDisabled', (tester) async {
        await _pump(
          tester,
          theme,
          PersonalTagSelector(selectedTagIds: const [], onChanged: (_) {}),
        );

        expect(
          _glyphColor(tester, find.byIcon(ButleryIcons.tag)),
          AppModeColors.textDisabled(theme.brightness),
        );
      });
    });
  }
}
