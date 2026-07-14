/// Widget tests for [CommentFormWidget]'s draft-persistence cycle (BUT-1058,
/// follow-up to BUT-917). The widget persists in-flight comment text per recipe
/// under `comment_draft_v1_<recipeId>` SharedPreferences keys: load on mount,
/// save on every keystroke, clear on successful post, isolated per recipe.
///
/// These assert data/persistence behaviour (TextField content + prefs values),
/// NOT visual appearance, so they need no human visual verification.
///
/// The viewmodel is faked via mocktail — the widget only reads a handful of
/// getters and records two calls (`updateNewCommentText`, `postComment`).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/fake_permission_gateways.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _FakeSocialRecipeViewModel extends Mock
    implements SocialRecipeViewModel {}

const _kDraftPrefix = 'comment_draft_v1_';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  late _FakeSocialRecipeViewModel vm;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    // The widget resolves ImagePickerService + StorageService from the
    // production ServiceLocator in initState (BUT-1049 image attachments).
    // TestServiceLocator registers mock versions of both; bridging the
    // production ServiceLocator to the same GetIt instance makes
    // `ServiceLocator.get<T>()` in widget code resolve them.
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());

    vm = _FakeSocialRecipeViewModel();
    // Default getter stubs — the widget reads these in build(). Overridden
    // per-test where the case needs a specific value (e.g. non-empty text to
    // enable the send button).
    when(() => vm.isReplying).thenReturn(false);
    when(() => vm.isPostingComment).thenReturn(false);
    when(() => vm.newCommentText).thenReturn('');
    when(() => vm.currentUser).thenReturn(null);
    when(() => vm.updateNewCommentText(any())).thenReturn(null);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  CommentFormWidget buildWidget(
    String recipeId, {
    PermissionGateway? voiceGateway,
  }) => CommentFormWidget(
    socialViewModel: vm,
    recipeId: recipeId,
    onShowMessage: (_, {bool isError = false}) {},
    voicePermissionGateway: voiceGateway ?? const DefaultPermissionGateway(),
  );

  /// Stubs the shared MockVoiceCaptureService for a successful dictation
  /// round trip.
  void stubVoiceCapture(String transcript) {
    final voice =
        production.ServiceLocator.get<VoiceCaptureService>()
            as MockVoiceCaptureService;
    when(voice.prepareModel).thenAnswer((_) async => true);
    when(
      () => voice.startRecording(
        onAutoStopped: any(named: 'onAutoStopped'),
        maxDuration: any(named: 'maxDuration'),
      ),
    ).thenAnswer((_) async => true);
    when(voice.stopAndTranscribe).thenAnswer((_) async => transcript);
  }

  group('voice notes (voice plan Phase 2b)', () {
    testWidgets(
      'dictated text lands APPENDED and EDITABLE, flowing through the same '
      'onChanged path as typing (draft + VM + gates see identical input)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        stubVoiceCapture('gott men lite salt');

        await tester.pumpWidget(
          _wrap(
            buildWidget(
              'r1',
              voiceGateway: GrantedPermissionGateway(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byTooltip('Tala in en kommentar'),
          findsOneWidget,
          reason:
              'the comment surface must carry its OWN copy, not the '
              'weekly-menu default (per-surface mic purpose, Store/DPO)',
        );

        await tester.enterText(find.byType(TextField), 'Provade igår.');
        await tester.pumpAndSettle();

        // Record → stop (the mic toggles like the other voice surfaces).
        await tester.tap(find.byIcon(Icons.mic_none));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pumpAndSettle();

        const combined = 'Provade igår. gott men lite salt';
        expect(
          find.text(combined),
          findsOneWidget,
          reason:
              'the transcript must append to typed text in the EDITABLE '
              'field — dictation never replaces or posts on its own',
        );
        verify(() => vm.updateNewCommentText(combined)).called(1);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('${_kDraftPrefix}r1'),
          combined,
          reason:
              'a dictated draft persists exactly like a typed one — the '
              'downstream profanity/maturity gates see it as typed text',
        );
      },
    );

    testWidgets(
      'a transcript arriving while a post is in flight SURVIVES the '
      'post-success cleanup (only what was sent is removed)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        // Transcription resolves only when the test says so — lets us land
        // the transcript while postComment is still awaiting.
        final transcriptGate = Completer<String?>();
        final voice =
            production.ServiceLocator.get<VoiceCaptureService>()
                as MockVoiceCaptureService;
        when(voice.prepareModel).thenAnswer((_) async => true);
        when(
          () => voice.startRecording(
            onAutoStopped: any(named: 'onAutoStopped'),
            maxDuration: any(named: 'maxDuration'),
          ),
        ).thenAnswer((_) async => true);
        when(voice.stopAndTranscribe).thenAnswer((_) => transcriptGate.future);

        final postGate = Completer<void>();
        when(() => vm.newCommentText).thenReturn('Skickas nu');
        when(
          () => vm.postComment(any(), imageUrls: any(named: 'imageUrls')),
        ).thenAnswer((_) => postGate.future);

        await tester.pumpWidget(
          _wrap(buildWidget('r1', voiceGateway: GrantedPermissionGateway())),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Skickas nu');
        await tester.pumpAndSettle();

        // Start dictation, then hit send while transcription is pending.
        await tester.tap(find.byIcon(Icons.mic_none));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Transcript lands while the post is in flight...
        transcriptGate.complete('och lite till');
        await tester.pump();
        // ...then the post succeeds.
        postGate.complete();
        await tester.pumpAndSettle();

        expect(
          find.text('och lite till'),
          findsOneWidget,
          reason:
              'the dictated text must survive the success cleanup — only '
              'the sent text is removed, never what arrived during the post',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('${_kDraftPrefix}r1'),
          'och lite till',
          reason: 'the surviving remainder stays draft-persisted',
        );
      },
    );

    testWidgets('denied mic leaves the typed text untouched', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        _wrap(
          buildWidget(
            'r1',
            voiceGateway: PermanentlyDeniedPermissionGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Skrivet för hand');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      expect(
        find.text('Skrivet för hand'),
        findsOneWidget,
        reason: 'voice denial never clears or alters typed input',
      );
    });
  });

  testWidgets('load on mount: seeds TextField from prefs and syncs VM', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      '${_kDraftPrefix}r1': 'half-written',
    });

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    // _loadDraft is async (SharedPreferences.getInstance) — let it settle.
    await tester.pumpAndSettle();

    expect(
      find.text('half-written'),
      findsOneWidget,
      reason: 'mounted draft must populate the TextField',
    );
    verify(() => vm.updateNewCommentText('half-written')).called(1);
  });

  testWidgets('save on edit: each keystroke persists to prefs', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('${_kDraftPrefix}r1'),
      'fresh',
      reason: 'onChanged must persist the draft under the recipe key',
    );
  });

  testWidgets('clear on post-success: draft key is removed', (tester) async {
    SharedPreferences.setMockInitialValues({
      '${_kDraftPrefix}r1': 'about to send',
    });
    // Send button is enabled only when newCommentText is non-empty + not posting.
    when(() => vm.newCommentText).thenReturn('about to send');
    when(
      () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(buildWidget('r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    verify(
      () => vm.postComment('r1', imageUrls: any(named: 'imageUrls')),
    ).called(1);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('${_kDraftPrefix}r1'),
      isNull,
      reason: 'successful post must clear the persisted draft',
    );
  });

  testWidgets(
    'per-recipe isolation: r2 ignores r1 draft and leaves it intact',
    (tester) async {
      SharedPreferences.setMockInitialValues({'${_kDraftPrefix}r1': 'r1 only'});

      await tester.pumpWidget(_wrap(buildWidget('r2')));
      await tester.pumpAndSettle();

      // r2's field stays empty — it must not read r1's draft.
      expect(
        find.text('r1 only'),
        findsNothing,
        reason: 'a different recipe must not load another recipe\'s draft',
      );
      verifyNever(() => vm.updateNewCommentText('r1 only'));

      // r1's draft is untouched by mounting r2.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${_kDraftPrefix}r1'),
        'r1 only',
        reason: 'mounting r2 must not disturb r1\'s persisted draft',
      );
    },
  );

  // BUT-1049: image-attachment behaviour. These prove the upload→post contract,
  // NOT visual appearance.
  group('image attachments', () {
    late File tempImage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      when(() => vm.newCommentText).thenReturn('with photo');
      when(
        () => vm.postComment(any(), imageUrls: any(named: 'imageUrls')),
      ).thenAnswer((_) async {});

      tempImage = File(
        '${Directory.systemTemp.path}/comment_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempImage.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);
    });

    tearDown(() async {
      if (await tempImage.exists()) await tempImage.delete();
    });

    testWidgets(
      'upload failure: comment is NOT posted and an error is surfaced',
      (tester) async {
        final picker = ServiceLocator.get<ImagePickerService>();
        final storage = ServiceLocator.get<StorageService>();
        when(
          () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
        ).thenAnswer((_) async => [tempImage]);
        // Upload returns null → the composer must abort the post.
        when(
          () => storage.uploadCommentImage(
            any(),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => null);

        var errorShown = false;
        await tester.pumpWidget(
          _wrap(
            CommentFormWidget(
              socialViewModel: vm,
              recipeId: 'r1',
              onShowMessage: (_, {bool isError = false}) {
                if (isError) errorShown = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        expect(
          errorShown,
          isTrue,
          reason: 'a failed image upload must surface an error',
        );
        verifyNever(
          () => vm.postComment(any(), imageUrls: any(named: 'imageUrls')),
        );
      },
    );

    testWidgets(
      'cap: attach button disappears once maxImageUrls images are selected',
      (tester) async {
        final picker = ServiceLocator.get<ImagePickerService>();
        when(
          () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
        ).thenAnswer((_) async => [tempImage]);

        await tester.pumpWidget(_wrap(buildWidget('r1')));
        await tester.pumpAndSettle();

        // Attach is available below the cap; add one image per tap.
        for (var i = 0; i < RecipeComment.maxImageUrls; i++) {
          expect(
            find.byIcon(Icons.add_photo_alternate_outlined),
            findsOneWidget,
            reason: 'attach must stay available while below the cap (i=$i)',
          );
          await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
          await tester.pumpAndSettle();
        }

        // At the cap the composer must stop offering the attach affordance so a
        // 4th image can't be selected (RecipeComment asserts the cap at build).
        expect(
          find.byIcon(Icons.add_photo_alternate_outlined),
          findsNothing,
          reason: 'attach must disappear at maxImageUrls selected images',
        );
      },
    );

    testWidgets('upload success: posts with the uploaded URLs', (tester) async {
      final picker = ServiceLocator.get<ImagePickerService>();
      final storage = ServiceLocator.get<StorageService>();
      when(
        () => picker.pickMultipleImages(maxImages: any(named: 'maxImages')),
      ).thenAnswer((_) async => [tempImage]);
      when(
        () => storage.uploadCommentImage(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => 'https://example.test/comment_images/x.jpg');

      await tester.pumpWidget(_wrap(buildWidget('r1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      verify(
        () => vm.postComment(
          'r1',
          imageUrls: ['https://example.test/comment_images/x.jpg'],
        ),
      ).called(1);
    });
  });
}
