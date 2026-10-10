// BUT-1953: labels in the recipe-detail / image widgets that used to restate
// their visible text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/recipe_detail/recipe_detail_hero_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/components/image_grid_widgets.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/image_config.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  testWidgets('a hero button is announced once, as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Center(
          child: Semantics(
            identifier: 'btn-share-friends',
            button: true,
            child: RecipeHeroButton(
              icon: ButleryIcons.users,
              onPressed: () {},
              tooltip: 'Dela med vänner',
            ),
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Dela med vänner');
    expect(button, findsOneWidget);
    expect(announcedLines(tester, button), ['Dela med vänner']);
    expectActivatable(tester, button);
    handle.dispose();
  });

  testWidgets('the grid add slot names the slot, the text names the action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ImageGridWidgets.buildAddImageButton(
          config: const ImageConfig(type: ImageType.recipeEdit),
          remainingSlots: 3,
          isLoading: false,
          onAddImage: () {},
        ),
      ),
    );

    final slot = find.bySemanticsLabel(RegExp('^Bild'));
    expect(slot, findsOneWidget);
    expect(announcedLines(tester, slot), contains('Lägg till (3)'));
    expectNothingAnnouncedTwice(tester, slot);
    expectActivatable(tester, slot);
    handle.dispose();
  });

  testWidgets('the grid add slot says "adding" once while loading', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ImageGridWidgets.buildAddImageButton(
          config: const ImageConfig(type: ImageType.recipeEdit),
          remainingSlots: 3,
          isLoading: true,
          onAddImage: () {},
        ),
      ),
    );

    final slot = find.bySemanticsLabel(RegExp('^Bild'));
    expect(slot, findsOneWidget);
    expectNothingAnnouncedTwice(tester, slot);
    expect(
      announcedLines(tester, slot).where((l) => l.contains('Lägger till')),
      hasLength(1),
    );
    expect(
      tester.getSemantics(slot).getSemanticsData().flagsCollection.isLiveRegion,
      isTrue,
    );
    // The plate line is its own live-region node unless excluded: a second
    // focus stop reading the same text.
    expect(find.bySemanticsLabel(RegExp('Lägger till')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a grid item announces its badge and its remove button once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SizedBox(
          width: 200,
          height: 160,
          child: Builder(
            builder: (context) => ImageGridWidgets.buildGridImageItem(
              context: context,
              index: 0,
              imageUrl: '/nonexistent/image.jpg',
              config: const ImageConfig(type: ImageType.recipeEdit),
              isPrimary: true,
              showEditControls: true,
              onPrimaryImageChanged: (_) {},
              onImageTap: (_) {},
              onRemoveImage: (_) {},
            ),
          ),
        ),
      ),
    );

    final item = find.bySemanticsLabel(RegExp('Primär'));
    expect(item, findsOneWidget);
    expect(announcedLines(tester, item), contains('Primär'));
    expectNothingAnnouncedTwice(tester, item);
    expectActivatable(tester, item);

    final remove = find.byTooltip('Ta bort bild');
    expect(remove, findsOneWidget);
    expect(announcedLines(tester, remove), ['Ta bort bild']);
    expectNothingAnnouncedTwice(tester, remove);
    expectActivatable(tester, remove);
    handle.dispose();
  });

  testWidgets('bulk and overlay upload buttons are announced once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Column(
          children: [
            UploadProgressWidgets.buildBulkActionButton(
              icon: ButleryIcons.x,
              label: 'Försök igen alla',
              onTap: () {},
              color: Colors.red,
            ),
            UploadProgressWidgets.buildUploadActionButton(
              icon: ButleryIcons.x,
              label: 'Försök igen',
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    for (final text in ['Försök igen alla', 'Försök igen']) {
      final button = find.bySemanticsLabel(text);
      expect(button, findsOneWidget, reason: text);
      expect(announcedLines(tester, button), [text]);
      expectActivatable(tester, button);
    }
    handle.dispose();
  });
}
