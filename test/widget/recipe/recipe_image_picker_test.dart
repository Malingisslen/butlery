/// RecipeImagePicker.showAndPick: the sheet's rows route to the matching
/// view-model pick, and cancelling picks nothing.
///
/// `showAndPick` returns void, so the sheet's result ('camera' / 'gallery' /
/// null) is observed through which view-model method the choice reaches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/recipe/recipe_image_picker.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRecipeFormViewModel extends Mock implements RecipeFormViewModel {}

class _FakeContext extends Fake implements BuildContext {}

void main() {
  late _MockRecipeFormViewModel vm;

  setUpAll(() => registerFallbackValue(_FakeContext()));

  setUp(() {
    vm = _MockRecipeFormViewModel();
    when(
      () => vm.pickImageFromCamera(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => vm.pickImageFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => vm.pickMultipleImagesFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required int existingImages,
    bool canAddMore = true,
  }) async {
    when(() => vm.canAddMoreImages).thenReturn(canAddMore);
    when(() => vm.imageUrls).thenReturn(
      List.generate(existingImages, (i) => 'https://x/$i.jpg'),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                RecipeImagePicker.showAndPick(context: context, viewModel: vm),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void verifyNothingPicked() {
    verifyNever(
      () => vm.pickImageFromCamera(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    verifyNever(
      () => vm.pickImageFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    verifyNever(
      () => vm.pickMultipleImagesFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
  }

  testWidgets('the camera row takes a photo and touches no gallery pick', (
    tester,
  ) async {
    await openSheet(tester, existingImages: 0);

    await tester.tap(find.text('Ta foto'));
    await tester.pumpAndSettle();

    verify(
      () => vm.pickImageFromCamera(any(), askAgain: false),
    ).called(1);
    verifyNever(
      () => vm.pickImageFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    verifyNever(
      () => vm.pickMultipleImagesFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    expect(find.text('Ta foto'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('the gallery row picks several images while slots remain', (
    tester,
  ) async {
    await openSheet(tester, existingImages: 2);

    await tester.tap(find.text('Välj upp till 3 bilder'));
    await tester.pumpAndSettle();

    verify(
      () => vm.pickMultipleImagesFromGallery(any(), askAgain: false),
    ).called(1);
    verifyNever(
      () => vm.pickImageFromCamera(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    verifyNever(
      () => vm.pickImageFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
  });

  testWidgets('the gallery row picks a single image at the last free slot', (
    tester,
  ) async {
    await openSheet(tester, existingImages: RecipeFormViewModel.maxImages - 1);

    await tester.tap(find.text('Välj upp till 1 bild'));
    await tester.pumpAndSettle();

    verify(
      () => vm.pickImageFromGallery(any(), askAgain: false),
    ).called(1);
    verifyNever(
      () => vm.pickMultipleImagesFromGallery(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
    verifyNever(
      () => vm.pickImageFromCamera(
        any(),
        askAgain: any(named: 'askAgain'),
      ),
    );
  });

  testWidgets('the "up to N" subtitle counts the free slots', (tester) async {
    await openSheet(tester, existingImages: 0);

    expect(
      find.text('Välj upp till ${RecipeFormViewModel.maxImages} bilder'),
      findsOneWidget,
    );
  });

  testWidgets('a full album shows no "up to N" subtitle', (tester) async {
    await openSheet(
      tester,
      existingImages: RecipeFormViewModel.maxImages,
      canAddMore: false,
    );

    expect(find.textContaining('Välj upp till'), findsNothing);
    // Title and fallback subtitle are the same Swedish text.
    expect(find.text('Välj från galleri'), findsNWidgets(2));
  });

  testWidgets('Avbryt closes the sheet and picks nothing', (tester) async {
    await openSheet(tester, existingImages: 0);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.text('Ta foto'), findsNothing, reason: 'the sheet closed');
    verifyNothingPicked();
  });

  testWidgets('dismissing the sheet by its barrier picks nothing', (
    tester,
  ) async {
    await openSheet(tester, existingImages: 0);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Ta foto'), findsNothing, reason: 'the sheet closed');
    verifyNothingPicked();
  });
}
