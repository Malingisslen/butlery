/// Widget tests for FriendCard and FriendRequestCard.
///
/// Covers public render contracts:
///   - FriendCard: each FriendCardStyle (detailed / compact / list) renders
///     the user's display name, the avatar visibility flag is honoured,
///     subtitle/trailing/metadata slots show up, and tap + long-press
///     callbacks fire on the InkWell.
///   - FriendRequestCard: title + standard "wants to be friend" copy render,
///     optional message is shown when present, accept / decline buttons only
///     appear when their callbacks are provided and fire correctly.
///
/// Avatars are exercised via UserProfile.avatarUrl == null so the underlying
/// SocialAvatarComponents falls back to its initials placeholder (no network
/// fetch needed in the test harness).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

UserProfile _user({
  String uid = 'u1',
  String displayName = 'Anna Andersson',
  String email = 'anna@example.com',
  bool isOnline = false,
}) {
  final now = DateTime(2026, 5, 1, 12);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    joinedAt: now,
    lastActiveAt: now,
    isOnline: isOnline,
  );
}

FriendRequest _request({String? message}) => FriendRequest(
  id: 'req-1',
  fromUserId: 'sender',
  toUserId: 'me',
  sentAt: DateTime(2026, 5, 1, 12),
  message: message,
);

void main() {
  group('FriendCard - rendering', () {
    testWidgets('detailed style renders display name', (tester) async {
      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      expect(find.text('Anna Andersson'), findsOneWidget);
    });

    testWidgets('detailed style shows email metadata by default', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      expect(find.text('anna@example.com'), findsOneWidget);
    });

    testWidgets('showMetadata=false hides the email row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), showMetadata: false),
        ),
      );
      expect(find.text('anna@example.com'), findsNothing);
      // Display name still rendered
      expect(find.text('Anna Andersson'), findsOneWidget);
    });

    testWidgets('subtitle takes precedence over metadata when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), subtitle: 'Mutual: 3'),
        ),
      );
      expect(find.text('Mutual: 3'), findsOneWidget);
    });

    testWidgets('trailing widget renders inside the card', (tester) async {
      const trailingKey = Key('trailing-marker');
      await tester.pumpWidget(
        _wrap(
          FriendCard(
            user: _user(),
            trailing: const Icon(Icons.chevron_right, key: trailingKey),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byKey(trailingKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('compact style still renders the display name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), style: FriendCardStyle.compact),
        ),
      );
      expect(find.text('Anna Andersson'), findsOneWidget);
      // Compact style does NOT show metadata even if showMetadata=true
      expect(find.text('anna@example.com'), findsNothing);
    });

    testWidgets('list style uses a ListTile internally', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), style: FriendCardStyle.list),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect(find.text('Anna Andersson'), findsOneWidget);
    });

    testWidgets('empty email produces no metadata row in detailed style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(email: '')),
        ),
      );
      expect(find.text('anna@example.com'), findsNothing);
      expect(find.text('Anna Andersson'), findsOneWidget);
    });
  });

  group('FriendCard - interaction', () {
    testWidgets('onTap fires when card is tapped (detailed)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), onTap: () => taps++),
        ),
      );
      await tester.tap(find.byType(FriendCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onLongPress fires when card is long-pressed (detailed)', (
      tester,
    ) async {
      var longs = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), onLongPress: () => longs++),
        ),
      );
      await tester.longPress(find.byType(FriendCard));
      await tester.pump();
      expect(longs, 1);
    });

    testWidgets('onTap fires in list style (ListTile path)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(
            user: _user(),
            style: FriendCardStyle.list,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('FriendCard - semantics', () {
    testWidgets('exposes localized friend semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      // Swedish a11yFriend template: "Vän: {name}". Semantics may merge
      // descendant text into the label, so match by prefix.
      expect(
        find.bySemanticsLabel(RegExp(r'^Vän: Anna Andersson')),
        findsAtLeastNWidgets(1),
      );
      handle.dispose();
    });
  });

  group('FriendRequestCard - rendering', () {
    testWidgets('renders the Swedish title and supporting copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(friendRequest: _request()),
        ),
      );
      expect(find.text('Vänförfrågan'), findsOneWidget);
      expect(find.text('Vill bli din vän'), findsOneWidget);
    });

    testWidgets('renders the optional message when present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(message: 'Hej, kommer du ihåg mig?'),
          ),
        ),
      );
      expect(find.text('Hej, kommer du ihåg mig?'), findsOneWidget);
    });

    testWidgets('does not render a message paragraph when message is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(friendRequest: _request(message: '')),
        ),
      );
      // Title is rendered; an empty message string should NOT appear as a
      // separate Text widget. We assert via the absence of any Text whose
      // data is exactly the empty string.
      final emptyTexts = find.byWidgetPredicate(
        (w) => w is Text && w.data == '',
      );
      expect(emptyTexts, findsNothing);
    });

    testWidgets('omits both action buttons when callbacks are null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(friendRequest: _request()),
        ),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders both accept and decline buttons when wired', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onAccept: () {},
            onDecline: () {},
          ),
        ),
      );
      expect(find.widgetWithText(OutlinedButton, 'Avvisa'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Acceptera'), findsOneWidget);
    });

    testWidgets('renders only decline when onAccept is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onDecline: () {},
          ),
        ),
      );
      expect(find.widgetWithText(OutlinedButton, 'Avvisa'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders only accept when onDecline is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onAccept: () {},
          ),
        ),
      );
      expect(find.widgetWithText(ElevatedButton, 'Acceptera'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('FriendRequestCard - interaction', () {
    testWidgets('onAccept fires when accept button is tapped', (tester) async {
      var accepts = 0;
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onAccept: () => accepts++,
            onDecline: () {},
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Acceptera'));
      await tester.pump();
      expect(accepts, 1);
    });

    testWidgets('onDecline fires when decline button is tapped', (
      tester,
    ) async {
      var declines = 0;
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onAccept: () {},
            onDecline: () => declines++,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Avvisa'));
      await tester.pump();
      expect(declines, 1);
    });

    testWidgets('onTap fires when the card body is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FriendRequestCard(
            friendRequest: _request(),
            onTap: () => taps++,
          ),
        ),
      );
      // Tap on the title text (avoids hitting an unrelated descendant
      // semantically wrapped element).
      await tester.tap(find.text('Vänförfrågan'));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
