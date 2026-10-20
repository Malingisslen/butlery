/// BUT-2294 PR 7: with no connection, the comment form hands a comment that
/// carries photos to the queue instead of uploading, and says so. These tests
/// drive the real [CommentFormWidget] and assert what it sends to the view
/// model and what the user is told, not how it looks.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _FakeSocialRecipeViewModel extends Mock
    implements SocialRecipeViewModel {}

class _OfflineStub extends ChangeNotifier implements OfflineService {
  _OfflineStub({this.online = false, this.queueReady = true});

  final bool online;
  final bool queueReady;

  @override
  bool get isOnline => online;

  @override
  bool get isQueueReady => queueReady;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSocialRecipeViewModel vm;
  late File photo;
  late List<(String, bool)> shown;
  final sv = AppLocalizationsSv();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());

    shown = [];
    vm = _FakeSocialRecipeViewModel();
    when(() => vm.isReplying).thenReturn(false);
    when(() => vm.isPostingComment).thenReturn(false);
    when(() => vm.newCommentText).thenReturn('Mycket gott!');
    when(() => vm.currentUser).thenReturn(null);
    when(() => vm.updateNewCommentText(any())).thenReturn(null);
    when(
      () => vm.postComment(any(), imageUrls: any(named: 'imageUrls')),
    ).thenAnswer((_) async {});
    when(
      () => vm.queueCommentOffline(
        any(),
        recipeName: any(named: 'recipeName'),
        imagePaths: any(named: 'imagePaths'),
      ),
    ).thenAnswer((_) async {});

    photo = File(
      '${Directory.systemTemp.path}/comment_queue_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    final picker = ServiceLocator.get<ImagePickerService>();
    when(
      () => picker.pickMultipleImagesWithOutcome(
        maxImages: any(named: 'maxImages'),
        rationale: any(named: 'rationale'),
      ),
    ).thenAnswer(
      (_) async => ImagePickOutcome(
        permission: OsPermissionOutcome.granted,
        files: [photo],
      ),
    );
  });

  tearDown(() async {
    if (photo.existsSync()) photo.deleteSync();
    TestServiceLocator.unregister<OfflineService>();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> attachAndSend(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: CommentFormWidget(
            socialViewModel: vm,
            recipeId: 'r1',
            recipeName: 'Kladdkaka',
            onShowMessage: (message, {bool isError = false}) =>
                shown.add((message, isError)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mycket gott!');
    await tester.tap(find.byIcon(ButleryIcons.camera));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(ButleryIcons.send));
    await tester.pumpAndSettle();
  }

  void verifyNothingUploadedOrPosted() {
    verifyNever(
      () => vm.postComment(any(), imageUrls: any(named: 'imageUrls')),
    );
    verifyNever(
      () => ServiceLocator.get<StorageService>().uploadCommentImage(
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    );
  }

  testWidgets('offline with a photo: the comment is queued with the recipe '
      'name and the picked file, nothing is uploaded or posted, and the form '
      'says it waits', (tester) async {
    TestServiceLocator.registerMock<OfflineService>(_OfflineStub());

    await attachAndSend(tester);

    verify(
      () => vm.queueCommentOffline(
        'r1',
        recipeName: 'Kladdkaka',
        imagePaths: [photo.path],
      ),
    ).called(1);
    verifyNothingUploadedOrPosted();
    expect(shown, [(sv.commentQueuedOffline, false)]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('offline with a comment already waiting: the waiting notice, '
      'the typed text stays and the photo stays attached', (tester) async {
    TestServiceLocator.registerMock<OfflineService>(_OfflineStub());
    when(
      () => vm.queueCommentOffline(
        any(),
        recipeName: any(named: 'recipeName'),
        imagePaths: any(named: 'imagePaths'),
      ),
    ).thenThrow(const CommentAwaitingSendException());

    await attachAndSend(tester);

    expect(shown, [(sv.commentWaitingForNetwork, false)]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Mycket gott!',
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('offline and the queue fails: an error is shown and the text '
      'stays', (tester) async {
    TestServiceLocator.registerMock<OfflineService>(_OfflineStub());
    when(
      () => vm.queueCommentOffline(
        any(),
        recipeName: any(named: 'recipeName'),
        imagePaths: any(named: 'imagePaths'),
      ),
    ).thenThrow(StateError('disk full'));

    await attachAndSend(tester);

    expect(shown, [(sv.commentCouldNotPost, true)]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Mycket gott!',
    );
  });

  testWidgets('offline where there is no queue (the web): nothing is queued, '
      'the upload is tried as before', (tester) async {
    TestServiceLocator.registerMock<OfflineService>(
      _OfflineStub(queueReady: false),
    );
    final storage = ServiceLocator.get<StorageService>();
    when(
      () => storage.uploadCommentImage(
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => null);

    await attachAndSend(tester);

    verifyNever(
      () => vm.queueCommentOffline(
        any(),
        recipeName: any(named: 'recipeName'),
        imagePaths: any(named: 'imagePaths'),
      ),
    );
    expect(shown, [(sv.commentImageUploadError, true)]);
  });

  testWidgets('online: the photos go up and the comment is posted, nothing is '
      'queued', (tester) async {
    TestServiceLocator.registerMock<OfflineService>(
      _OfflineStub(online: true),
    );
    final storage = ServiceLocator.get<StorageService>();
    when(
      () => storage.uploadCommentImage(
        any(),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => 'https://img/1.jpg');

    await attachAndSend(tester);

    verifyNever(
      () => vm.queueCommentOffline(
        any(),
        recipeName: any(named: 'recipeName'),
        imagePaths: any(named: 'imagePaths'),
      ),
    );
    verify(
      () => vm.postComment('r1', imageUrls: ['https://img/1.jpg']),
    ).called(1);
  });
}
