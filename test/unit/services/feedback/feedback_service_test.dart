import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/services/feedback/feedback_service.dart';
import 'package:butlery/services/feedback/interaction_logger.dart';

class _MockFeedbackRepository extends Mock implements FeedbackRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeEntry extends Fake implements FeedbackEntry {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeEntry()));

  late _MockFeedbackRepository repository;
  late _MockAuthRepository auth;
  late InteractionLogger logger;
  late FeedbackService service;

  setUp(() {
    repository = _MockFeedbackRepository();
    auth = _MockAuthRepository();
    logger = InteractionLogger();
    when(() => repository.saveFeedback(any())).thenAnswer((_) async {});
    service = FeedbackService(
      interactionLogger: logger,
      feedbackRepository: repository,
      authRepository: auth,
    );
  });

  test('saves the entry through the injected repository for the injected '
      'user, with the injected logger\'s interactions', () async {
    when(() => auth.currentUserId).thenReturn('u1');
    logger.logInteraction('RecipeView', 'tap');

    final ok = await service.submitFeedback(
      category: FeedbackCategory.values.first,
      description: 'Knappen syns inte',
    );

    expect(ok, isTrue);
    final entry =
        verify(() => repository.saveFeedback(captureAny())).captured.single
            as FeedbackEntry;
    expect(entry.userId, 'u1');
    expect(entry.recentInteractions.single['screenName'], 'RecipeView');
  });

  test('refuses when nobody is signed in', () async {
    when(() => auth.currentUserId).thenReturn(null);

    final ok = await service.submitFeedback(
      category: FeedbackCategory.values.first,
      description: 'x',
    );

    expect(ok, isFalse);
    verifyNever(() => repository.saveFeedback(any()));
  });
}
