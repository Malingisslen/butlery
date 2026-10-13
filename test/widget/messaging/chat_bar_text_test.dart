// The words the page template's bar shows for a conversation: the name, and
// the participant count under it only for a group.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/widgets/messaging/chat_menu_button.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Conversation _conversation(List<String> participants, {String? title}) {
  final created = DateTime.utc(2026, 9, 20, 17);
  return Conversation(
    id: 'conv-1',
    title: title,
    participantIds: participants,
    participantDisplayNames: {for (final id in participants) id: id},
    participantAvatarUrls: {for (final id in participants) id: null},
    lastReadTimestamps: {for (final id in participants) id: created},
    createdAt: created,
    updatedAt: created,
    isGroup: participants.length > 2,
  );
}

void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('a group shows its participant count, a pair shows none', (
    tester,
  ) async {
    final context = await pumpContext(tester);

    expect(
      ChatBarText.participantLine(
        context,
        _conversation(['a', 'b', 'c'], title: 'Torsdagsklubben'),
      ),
      sv.chatParticipantCount(3),
    );
    expect(
      ChatBarText.participantLine(context, _conversation(['a', 'b'])),
      isNull,
    );
    expect(ChatBarText.participantLine(context, null), isNull);
  });

  testWidgets('the title is the conversation name, or the chat title before '
      'it has loaded', (tester) async {
    final context = await pumpContext(tester);

    expect(
      ChatBarText.title(
        context,
        _conversation(['a', 'b', 'c'], title: 'Torsdagsklubben'),
      ),
      'Torsdagsklubben',
    );
    expect(ChatBarText.title(context, null), sv.chatTitle);
  });
}
