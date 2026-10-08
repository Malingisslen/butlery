// BUT-2232 R8-5 = B: the voice import's record (stop) button and the
// upload's destructive button keep their red fill, now action.danger, and
// press one opaque step darker to action.dangerPressed, with
// text.onActionDanger on top, in light and in dark.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/import/voice_section_card.dart';

Widget _app(Brightness brightness, Widget child) => MaterialApp(
  theme: brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

({Color rest, Color pressed, Color on}) _danger(Brightness brightness) =>
    brightness == Brightness.dark
    ? (
        rest: AppColorsDark.actionDanger,
        pressed: AppColorsDark.actionDangerPressed,
        on: AppColorsDark.onActionDanger,
      )
    : (
        rest: AppColors.actionDanger,
        pressed: AppColors.actionDangerPressed,
        on: AppColors.onActionDanger,
      );

/// The resting fill under [inkWell] and what it draws while pressed.
({Color? rest, Color? pressed}) _fills(WidgetTester tester, Finder inkWell) {
  final material = tester.widget<Material>(
    find.ancestor(of: inkWell, matching: find.byType(Material)).first,
  );
  final ink = tester.widget<InkWell>(inkWell);
  return (
    rest: material.color,
    pressed: ink.overlayColor?.resolve({WidgetState.pressed}),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the voice stop button is action.danger', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          brightness,
          VoiceSectionCard(
            index: 0,
            title: 'Ingredienser',
            prompt: 'Säg ingredienserna',
            state: VoiceSectionState.recording,
            isDone: false,
            enabled: true,
            controller: TextEditingController(),
            onMicTap: () {},
            onChanged: (_) {},
          ),
        ),
      );
      final stop = find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.stop,
        ),
        matching: find.byType(InkWell),
      );
      final fills = _fills(tester, stop.first);
      final want = _danger(brightness);
      expect(fills.rest, want.rest);
      expect(fills.pressed, want.pressed);
      final icon = tester.widget<ButleryIcon>(
        find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.stop,
        ),
      );
      expect(icon.color, want.on);
    });

    testWidgets(
      '${brightness.name}: the upload destructive button is action.danger',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            brightness,
            UploadProgressWidgets.buildUploadActionButton(
              icon: ButleryIcons.x,
              label: 'Ta bort',
              onTap: () {},
              isDestructive: true,
            ),
          ),
        );
        final fills = _fills(tester, find.byType(InkWell).first);
        final want = _danger(brightness);
        expect(fills.rest, want.rest);
        expect(fills.pressed, want.pressed);
        expect(tester.widget<Text>(find.text('Ta bort')).style?.color, want.on);
      },
    );

    // The paper button's press on a photo is not decided, so it shows none:
    // pressed is the same paper as at rest.
    testWidgets('${brightness.name}: the paper upload button shows no press', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          brightness,
          UploadProgressWidgets.buildUploadActionButton(
            icon: ButleryIcons.refreshCw,
            label: 'Försök igen',
            onTap: () {},
          ),
        ),
      );
      final fills = _fills(tester, find.byType(InkWell).first);
      expect(fills.rest, AppModeColors.surfacePaperOnPhoto());
      expect(fills.pressed, AppModeColors.surfacePaperOnPhoto());
    });
  }
}
