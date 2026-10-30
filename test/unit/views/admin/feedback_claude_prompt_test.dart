// Megagenomgång A7: "Kopiera för Claude" must not carry the reporter's
// e-mail address.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/views/admin/feedback_inbox_rows.dart';

void main() {
  test('the copied prompt leaves the reporter e-mail out', () {
    final entry = FeedbackEntry(
      id: 'f1',
      userId: 'u1',
      category: FeedbackCategory.bug,
      description: 'Appen kraschar',
      email: 'rapportor@example.com',
      recentInteractions: const [],
      createdAt: DateTime(2026, 10, 13),
    );

    final prompt = FeedbackRow.buildClaudePrompt(entry);

    expect(prompt, isNot(contains('rapportor@example.com')));
    expect(prompt, isNot(contains('E-post')));
    expect(prompt, contains('Appen kraschar'));
    expect(prompt, contains('Feedback-ID: f1'));
  });
}
