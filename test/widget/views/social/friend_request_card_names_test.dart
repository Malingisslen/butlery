// BUT-2248: on an incoming friend request, Acceptera and Avböj carry the
// person's name for a screen reader, so stepping between rows in a list of
// requests says whose request each button answers. The visible words stay
// "Acceptera" and "Avböj".

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';

class _MockFriendsVm extends Mock implements FriendsViewModel {}

const _name = 'Erik Sandell';

Future<void> _pump(WidgetTester tester, {Locale locale = const Locale('sv')}) {
  final vm = _MockFriendsVm();
  when(() => vm.getUserProfile(any())).thenReturn(null);
  when(() => vm.getDisplayNameForUser(any())).thenReturn(_name);
  when(() => vm.isLoading).thenReturn(false);
  final request = FriendRequest(
    id: 'r1',
    fromUserId: 'erik',
    toUserId: 'me',
    sentAt: DateTime.utc(2026, 10, 5, 9),
    expiresAt: DateTime.utc(2026, 11, 5, 9),
  );
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => FriendRequestCard.buildIncomingCard(
              context,
              request,
              vm,
              false,
              (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// The labels of every button node a screen reader can land on whose name
/// begins with [word]. An outlined action button is two nested button nodes
/// (the action button's own Semantics around the OutlinedButton), and each
/// one must carry the name.
List<String> _buttonLabels(WidgetTester tester, String word) {
  final labels = <String>[];
  bool visit(SemanticsNode node) {
    if (node.flagsCollection.isButton && node.label.startsWith(word)) {
      labels.add(node.label);
    }
    node.visitChildren(visit);
    return true;
  }

  var root = tester.getSemantics(find.text(word));
  while (root.parent != null) {
    root = root.parent!;
  }
  visit(root);
  return labels;
}

void _expectNamed(WidgetTester tester, String word) {
  final labels = _buttonLabels(tester, word);
  expect(labels, isNotEmpty, reason: word);
  expect(labels, everyElement('$word $_name'), reason: word);
}

void main() {
  testWidgets('both buttons are read with the name, shown without it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('Acceptera'), findsOneWidget);
    expect(find.text('Avböj'), findsOneWidget);
    _expectNamed(tester, 'Acceptera');
    _expectNamed(tester, 'Avböj');
    handle.dispose();
  });

  testWidgets('the English buttons name the person too', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('en'));

    _expectNamed(tester, 'Accept');
    _expectNamed(tester, 'Decline');
    handle.dispose();
  });
}
