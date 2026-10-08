/// BUT-2160 · flow 07 on recipe images (flows-roles-budget.md:98-106).
///
/// - The image manager keeps what the camera or library answered instead of
///   dropping a plain no, keeps limited access as its own state, and clears
///   the notice on a granted pick. "Fråga igen" asks without our
///   explanation (produktregler.md:683).
/// - The editor's notice offers "Fråga igen" on the source that was
///   refused, the library after a refused camera, and no fallback after a
///   refused library (decision A, 2026-10-07).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/media_permission_notice.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/recipe/recipe_image_permission_notice.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _MockUploadService extends Mock implements ImageUploadService {}

class _MockRecipeFormViewModel extends Mock implements RecipeFormViewModel {}

class _FakeContext extends Fake implements BuildContext {}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ctx;
}

/// The manager debounces its other notifications by 50 ms; let them land.
Future<void> _flush(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 60));

void main() {
  final sv = AppLocalizationsSv();
  late MockImagePickerService picker;
  late RecipeImageManager manager;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(_FakeContext());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    picker = MockFactory.createImagePickerService();
    manager = RecipeImageManager(
      uploadService: _MockUploadService(),
      storageService: MockFactory.createStorageService(),
      imagePickerService: picker,
    );
  });

  tearDown(() async {
    manager.dispose();
    await TestServiceLocator.reset();
  });

  void answerSingle(OsPermissionOutcome outcome) {
    when(
      () => picker.pickImageWithOutcome(
        any(),
        rationale: any(named: 'rationale'),
        enableCrop: any(named: 'enableCrop'),
      ),
    ).thenAnswer((_) async => ImagePickOutcome(permission: outcome));
  }

  void answerMultiple(OsPermissionOutcome outcome) {
    when(
      () => picker.pickMultipleImagesWithOutcome(
        maxImages: any(named: 'maxImages'),
        rationale: any(named: 'rationale'),
      ),
    ).thenAnswer((_) async => ImagePickOutcome(permission: outcome));
  }

  group('RecipeImageManager · the permission notice', () {
    testWidgets('a camera no is kept, not dropped', (tester) async {
      final context = await _context(tester);
      answerSingle(OsPermissionOutcome.denied);

      await manager.pickImageFromCamera(context);

      await _flush(tester);

      expect(
        manager.permissionNotice,
        const MediaPermissionNotice(
          source: ImageSource.camera,
          outcome: OsPermissionOutcome.denied,
        ),
      );
      expect(manager.imageUrls, isEmpty);
    });

    testWidgets('limited access is its own state, even with nothing picked', (
      tester,
    ) async {
      final context = await _context(tester);
      answerMultiple(OsPermissionOutcome.limited);

      await manager.pickMultipleImagesFromGallery(context);

      await _flush(tester);

      expect(
        manager.permissionNotice,
        const MediaPermissionNotice(
          source: ImageSource.gallery,
          outcome: OsPermissionOutcome.limited,
        ),
      );
    });

    testWidgets('a granted pick clears the notice', (tester) async {
      final context = await _context(tester);
      answerSingle(OsPermissionOutcome.permanentlyDenied);
      await manager.pickImageFromGallery(context);
      await _flush(tester);
      expect(manager.permissionNotice, isNotNull);

      answerSingle(OsPermissionOutcome.granted);
      await manager.pickImageFromGallery(context);
      await _flush(tester);

      expect(manager.permissionNotice, isNull);
    });

    testWidgets('Fråga igen asks without our explanation; a first ask has it', (
      tester,
    ) async {
      final context = await _context(tester);
      answerSingle(OsPermissionOutcome.denied);
      answerMultiple(OsPermissionOutcome.denied);

      await manager.pickImageFromCamera(context);

      await _flush(tester);
      verify(
        () => picker.pickImageWithOutcome(
          ImageSource.camera,
          rationale: any(named: 'rationale', that: isNotNull),
          enableCrop: true,
        ),
      ).called(1);

      await manager.pickImageFromCamera(context, askAgain: true);

      await _flush(tester);
      await manager.pickImageFromGallery(context, askAgain: true);
      await _flush(tester);
      await manager.pickMultipleImagesFromGallery(context, askAgain: true);
      await _flush(tester);
      verify(
        () => picker.pickImageWithOutcome(
          ImageSource.camera,
          rationale: null,
          enableCrop: true,
        ),
      ).called(1);
      verify(
        () => picker.pickImageWithOutcome(
          ImageSource.gallery,
          rationale: null,
          enableCrop: true,
        ),
      ).called(1);
      verify(
        () => picker.pickMultipleImagesWithOutcome(
          maxImages: any(named: 'maxImages'),
          rationale: null,
        ),
      ).called(1);
    });
  });

  group('RecipeImagePermissionNotice', () {
    late _MockRecipeFormViewModel vm;

    setUp(() {
      vm = _MockRecipeFormViewModel();
      when(() => vm.imageManager).thenReturn(manager);
      when(() => vm.canAddMoreImages).thenReturn(true);
      when(() => vm.imageUrls).thenReturn(const []);
      when(
        () => vm.pickImageFromCamera(any(), askAgain: any(named: 'askAgain')),
      ).thenAnswer((_) async {});
      when(
        () => vm.pickMultipleImagesFromGallery(
          any(),
          askAgain: any(named: 'askAgain'),
        ),
      ).thenAnswer((_) async {});
    });

    testWidgets('nothing to say: no card', (tester) async {
      await tester.pumpWidget(_app(RecipeImagePermissionNotice(viewModel: vm)));

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets(
      'camera no: Fråga igen asks the camera again, and the library is the '
      'way on',
      (tester) async {
        final context = await _context(tester);
        answerSingle(OsPermissionOutcome.denied);
        await manager.pickImageFromCamera(context);
        await _flush(tester);

        await tester.pumpWidget(
          _app(RecipeImagePermissionNotice(viewModel: vm)),
        );

        expect(find.text(sv.permCameraDeniedImage), findsOneWidget);

        await tester.tap(find.text(sv.permAskAgain));
        verify(() => vm.pickImageFromCamera(any(), askAgain: true)).called(1);

        await tester.tap(find.text(sv.permFallbackGallery));
        verify(
          () => vm.pickMultipleImagesFromGallery(any(), askAgain: false),
        ).called(1);
      },
    );

    testWidgets('library no: Fråga igen asks the library, and no fallback', (
      tester,
    ) async {
      final context = await _context(tester);
      answerMultiple(OsPermissionOutcome.denied);
      await manager.pickMultipleImagesFromGallery(context);
      await _flush(tester);

      await tester.pumpWidget(_app(RecipeImagePermissionNotice(viewModel: vm)));

      expect(find.text(sv.permPhotosDeniedImage), findsOneWidget);
      expect(find.text(sv.permFallbackWriteYourself), findsNothing);
      expect(find.byType(TextButton), findsNothing);

      await tester.tap(find.text(sv.permAskAgain));
      verify(
        () => vm.pickMultipleImagesFromGallery(any(), askAgain: true),
      ).called(1);
    });

    testWidgets('limited: Välj fler bilder, and no fallback', (tester) async {
      final context = await _context(tester);
      answerMultiple(OsPermissionOutcome.limited);
      await manager.pickMultipleImagesFromGallery(context);
      await _flush(tester);

      await tester.pumpWidget(_app(RecipeImagePermissionNotice(viewModel: vm)));

      expect(find.text(sv.permPhotosLimited), findsOneWidget);
      expect(find.text(sv.permPhotosChooseMore), findsOneWidget);
      expect(find.text(sv.permAskAgain), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
