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
import 'package:butlery/widgets/image/image_gallery_widget.dart';
import 'package:butlery/widgets/image/avatar_image_widget.dart';
import 'package:butlery/widgets/image/image_picker_widget.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/components/edit_actions_panel.dart';
import 'package:butlery/widgets/image/components/empty_image_state.dart';
import 'package:butlery/services/upload/upload_models.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 image widget Semantics labels', () {
    testWidgets('image_gallery_widget — gallery add tile exposes label',
        (tester) async {
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

      expect(find.bySemanticsLabel(RegExp(r'^Lägg till bild i galleriet')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('avatar_image_widget — editable avatar exposes edit label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AvatarImageWidget.editable(
            displayName: 'Test User',
            onImageSelected: (_) {},
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'^Profilbild, tryck för att ändra')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('avatar_image_widget — readonly avatar exposes basic label',
        (tester) async {
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
          find.bySemanticsLabel(RegExp(r'^Profilbild(?!,)')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('image_picker_widget — picker open target exposes label',
        (tester) async {
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

      expect(find.bySemanticsLabel(RegExp(r'^Ta bort vald bild 1')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'upload_progress_widgets — bulk action button exposes label pass-through',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UploadProgressWidgets.buildBulkActionButton(
            icon: Icons.refresh,
            label: 'Försök igen alla',
            onTap: () {},
            color: Colors.blue,
          ),
        ),
      );

      expect(
          find.bySemanticsLabel(RegExp(r'^Försök igen alla')), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'upload_progress_widgets — upload action button exposes label pass-through',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UploadProgressWidgets.buildUploadActionButton(
            icon: Icons.refresh,
            label: 'Försök igen',
            onTap: () {},
            color: Colors.blue,
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp(r'^Försök igen')), findsOneWidget);
      handle.dispose();
    });

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
    });

    testWidgets('empty_image_state — idle empty state exposes add label',
        (tester) async {
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
          find.bySemanticsLabel(
              RegExp(r'^Lägg till bild, tryck för att välja')),
          findsOneWidget);
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
    });
  });
}
