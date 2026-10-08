// BUT-697 chunk-1: Semantics coverage for image widgets.
// Asserts that every tap target wrapped in this sprint exposes a
// localized Semantics label discoverable via `find.bySemanticsLabel`.
//
// Note: Semantics merging concatenates the wrapper label with descendant text
// labels (e.g. "Lägg till bild i galleriet\nLägg till"). The tests use
// RegExp prefix matchers so they assert the wrapper label is the leading text
// without depending on which descendants merge in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/image_gallery_widget.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/image_picker_widget.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/components/edit_actions_panel.dart';
import 'package:butlery/widgets/image/components/empty_image_state.dart';
import 'package:butlery/services/upload/upload_models.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

// No Scaffold: its page Material is paper, the same colour as the paper
// buttons, so a button that lost its own fill would still read as paper.
Widget _themed(ThemeData theme, Widget child) => createLocalizedTestApp(
  wrapInScaffold: false,
  child: Theme(
    data: theme,
    child: Material(type: MaterialType.transparency, child: child),
  ),
);

/// The nearest fill under [of]: a decorated Container, or a Material whose
/// colour an InkWell's pressed overlay paints on.
BoxDecoration _fillAround(WidgetTester tester, Finder of) {
  final nearest = tester.widget(
    find
        .ancestor(
          of: of,
          matching: find.byWidgetPredicate(
            (w) =>
                (w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).color != null) ||
                (w is Material &&
                    w.type != MaterialType.transparency &&
                    w.color != null),
          ),
        )
        .first,
  );
  return nearest is Material
      ? BoxDecoration(color: nearest.color)
      : (nearest as Container).decoration! as BoxDecoration;
}

Color? _textColor(WidgetTester tester, Finder of) =>
    tester.widget<Text>(of).style?.color;

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 image widget Semantics labels', () {
    testWidgets('image_gallery_widget — gallery add tile exposes label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ImageGalleryWidget.gallery(
            imageUrls: const [],
            showAddButton: true,
            onAddImage: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'^Lägg till bild i galleriet')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('avatar_image_widget — editable avatar exposes edit label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AvatarImageWidget.editable(
            displayName: 'Test User',
            onImageSelected: (_) {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'^Profilbild, tryck för att ändra')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('avatar_image_widget — readonly avatar exposes basic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AvatarImageWidget.readonly(
            displayName: 'Test User',
            onTap: () {},
          ),
        ),
      );

      // Read-only label is exactly "Profilbild"; ensure no edit hint slipped in.
      expect(
        find.bySemanticsLabel(RegExp(r'^Profilbild(?!,)')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('image_picker_widget — picker open target exposes label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ImagePickerWidget.picker(
            selectedImages: const [],
            onImagesSelected: (_) {},
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'^Välj bilder')), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'image_picker_widget — remove preview target exposes indexed label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ImagePickerWidget.picker(
              selectedImages: const ['https://example.com/a.jpg'],
              onImagesSelected: (_) {},
            ),
          ),
        );

        // The remove button exposes its localized label, but its GridView-item
        // Stack also holds the image's placeholder LoadingIndicator, whose
        // "Laddar" liveRegion label merges into the same semantics node and
        // sorts ahead of it. So we match the label as exposed (substring) rather
        // than as the leading text — the wrapper-label-leads convention used by
        // the other cases assumes only descendant merges, not a sibling
        // placeholder. (Unmasked when LoadingIndicator gained its liveRegion.)
        expect(
          find.bySemanticsLabel(RegExp(r'Ta bort vald bild 1')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'upload_progress_widgets — bulk action button exposes label pass-through',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UploadProgressWidgets.buildBulkActionButton(
              icon: ButleryIcons.refreshCw,
              label: 'Försök igen alla',
              onTap: () {},
              color: Colors.blue,
            ),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp(r'^Försök igen alla')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'upload_progress_widgets — upload action button exposes label pass-through',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UploadProgressWidgets.buildUploadActionButton(
              icon: ButleryIcons.refreshCw,
              label: 'Försök igen',
              onTap: () {},
            ),
          ),
        );

        expect(find.bySemanticsLabel(RegExp(r'^Försök igen')), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'edit_actions_panel — every action button forwards tooltip as label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const Stack(
              children: [
                EditActionsPanel(
                  canAddImage: true,
                  canSetPrimary: true,
                ),
              ],
            ),
          ),
        );

        // Three buttons rendered: Add, Set primary, Remove.
        expect(find.bySemanticsLabel(RegExp(r'Lägg till bild')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp(r'Ange som primär')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp(r'Ta bort bild')), findsWidgets);
        handle.dispose();
      },
    );

    testWidgets('empty_image_state — idle empty state exposes add label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: EmptyImageState(
            onTap: () {},
            isLoading: false,
            maxImages: 5,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'^Lägg till bild, tryck för att välja')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'upload_progress_widgets — overlay retry button surfaces retry label',
      (tester) async {
        final handle = tester.ensureSemantics();
        const failedStatus = ImageUploadStatus(
          state: ImageUploadState.failed,
          error: 'network failure',
        );
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 600,
              height: 400,
              child: Stack(
                children: [
                  UploadProgressWidgets.buildUploadProgressOverlay(
                    status: failedStatus,
                    imageUrl: 'https://example.com/x.jpg',
                    borderRadius: BorderRadius.zero,
                    onRetryUpload: (_) {},
                    onCancelUpload: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel(RegExp(r'Försök igen')), findsWidgets);
        handle.dispose();
      },
    );
  });

  // BUT-2183 5c: badges and controls on a photo are overlay.paperCard with
  // ink; what is not on a photo takes the step table's tokens.
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modes = ModeColors.of(theme.brightness);

    group('BUT-2183 5c image tokens ($name)', () {
      testWidgets('upload overlay: status pill and retry button are opaque '
          'paper (B102) with ink', (tester) async {
        const failedStatus = ImageUploadStatus(
          state: ImageUploadState.failed,
          error: 'network failure',
        );
        await tester.pumpWidget(
          _themed(
            theme,
            SizedBox(
              width: 600,
              height: 400,
              child: Stack(
                children: [
                  UploadProgressWidgets.buildUploadProgressOverlay(
                    status: failedStatus,
                    imageUrl: 'https://example.com/x.jpg',
                    borderRadius: BorderRadius.zero,
                    onRetryUpload: (_) {},
                    onCancelUpload: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        final pillText = find.text(failedStatus.statusDescription);
        expect(
          _fillAround(tester, pillText).color,
          AppModeColors.surfacePaperOnPhoto(),
        );
        expect(_textColor(tester, pillText), cs.primary);

        final retryText = find.text('Försök igen');
        expect(
          _fillAround(tester, retryText).color,
          AppModeColors.surfacePaperOnPhoto(),
        );
        expect(_textColor(tester, retryText), cs.primary);
      });

      testWidgets('upload queue banner: tint without a border, secondary '
          'detail text', (tester) async {
        await tester.pumpWidget(
          _themed(
            theme,
            UploadProgressWidgets.buildUploadQueueStatusBanner(
              uploadQueueStatus: 'Laddar upp 1 av 2',
              uploadManagementSummary: const {
                'progressText': '50 % klart',
                'overallProgress': 0.5,
                'active': 1,
              },
            ),
          ),
        );

        final box = _fillAround(tester, find.text('Laddar upp 1 av 2'));
        expect(box.color, modes.surfaceTintWarning);
        expect(box.border, isNull);
        expect(
          _textColor(tester, find.text('50 % klart')),
          cs.onSurfaceVariant,
        );
      });

      testWidgets('empty state: border.subtle, a plain disc and secondary '
          'text', (tester) async {
        await tester.pumpWidget(
          _themed(theme, const SizedBox(height: 300, child: EmptyImageState())),
        );

        final frame = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(EmptyImageState),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere(
              (d) => d.border != null && d.shape == BoxShape.rectangle,
            );
        expect((frame.border! as Border).top.color, cs.outlineVariant);

        final disc = _fillAround(
          tester,
          find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.camera,
          ),
        );
        expect(disc.shape, BoxShape.circle);
        expect(disc.color, cs.surface);
        expect(
          _textColor(tester, find.textContaining('upp till 5 bilder')),
          cs.onSurfaceVariant,
        );
      });

      testWidgets('picker: index badge on the photo is overlay.paperCard '
          'with ink', (tester) async {
        await tester.pumpWidget(
          _themed(
            theme,
            ImagePickerWidget.picker(
              selectedImages: const ['https://example.com/a.jpg'],
              onImagesSelected: (_) {},
            ),
          ),
        );

        final badgeText = find.text('1');
        expect(
          _fillAround(tester, badgeText).color,
          modes.overlayPaperCard,
        );
        expect(_textColor(tester, badgeText), cs.primary);
      });
    });
  }
}
