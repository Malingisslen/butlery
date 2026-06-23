/// Widget tests for PollMessageWidget — recipe-aware rendering (BUT-340).
///
/// Verifies:
/// - Recipe options render a thumbnail + title + portions metadata
/// - Plain-text polls render unchanged (no thumbnails, no portions row)
/// - Tapping a recipe option's thumbnail calls [onRecipeTap]
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Poll _recipePoll() {
  return Poll(
    id: 'poll-1',
    question: 'Vad ska vi äta?',
    creatorId: 'user-creator',
    createdAt: DateTime.now(),
    options: [
      PollOption(
        id: 'opt-1',
        text: 'Kycklinggryta med ris',
        recipeId: 'recipe-1',
        recipePortions: 4,
      ),
      PollOption(
        id: 'opt-2',
        text: 'Pasta bolognese',
        recipeId: 'recipe-2',
        recipePortions: 2,
      ),
    ],
  );
}

Poll _textPoll() {
  return Poll.create(
    question: 'Pizza or Sushi?',
    optionTexts: const ['Pizza', 'Sushi'],
    creatorId: 'user-creator',
  );
}

void main() {
  group('PollMessageWidget — recipe options', () {
    testWidgets('renders recipe titles + portions row for recipe options', (
      tester,
    ) async {
      final poll = _recipePoll();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: PollMessageWidget(
            poll: poll,
            currentUserId: 'viewer',
            isFromCurrentUser: false,
          ),
        ),
      );
      await tester.pump();

      // Recipe titles
      expect(find.text('Kycklinggryta med ris'), findsOneWidget);
      expect(find.text('Pasta bolognese'), findsOneWidget);

      // Portions metadata — "4 portioner" / "2 portioner" (Swedish label).
      expect(find.textContaining('4'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);

      // Question is rendered.
      expect(find.text('Vad ska vi äta?'), findsOneWidget);
    });

    testWidgets(
      'tapping a recipe option calls onRecipeTap when widget provides it',
      (tester) async {
        final poll = _recipePoll();
        String? tappedRecipeId;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: PollMessageWidget(
              poll: poll,
              currentUserId: 'viewer',
              isFromCurrentUser: false,
              onRecipeTap: (id) => tappedRecipeId = id,
            ),
          ),
        );
        await tester.pump();

        // Tap the fallback thumbnail of the first option (Icon restaurant_menu).
        final thumbnailIcons = find.byIcon(Icons.restaurant_menu);
        expect(thumbnailIcons, findsWidgets);
        await tester.tap(thumbnailIcons.first);
        await tester.pump();

        expect(tappedRecipeId, equals('recipe-1'));
      },
    );
  });

  group('PollMessageWidget — plain-text options (backward compat)', () {
    testWidgets('renders plain-text options without recipe chrome', (
      tester,
    ) async {
      final poll = _textPoll();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: PollMessageWidget(
            poll: poll,
            currentUserId: 'viewer',
            isFromCurrentUser: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sushi'), findsOneWidget);

      // Plain-text mode must not render the recipe fallback thumbnail icon.
      expect(find.byIcon(Icons.restaurant_menu), findsNothing);
    });
  });
}
