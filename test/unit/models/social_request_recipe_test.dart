import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/social_request.dart';

void main() {
  group('recipeShareRequest factory', () {
    test('sets type + payload fields', () {
      final r = SocialRequest.recipeShareRequest(
        fromUserId: 'a',
        toUserId: 'b',
        recipeId: 'r1',
        recipeTitle: 'Pannkakor',
      );
      expect(r.type, SocialRequestType.recipeShareRequest);
      expect(r.isRecipeShareRequest, isTrue);
      expect(r.recipeId, 'r1');
      expect(r.recipeTitle, 'Pannkakor');
    });

    test(
      'isRecipeShareRequest is false for friend and groupInvitation types',
      () {
        // Proves mutual exclusivity — a refactor collapsing the getter to `true`
        // or changing which enum value it checks would trip this.
        final friend = SocialRequest.friendRequest(
          fromUserId: 'a',
          toUserId: 'b',
        );
        expect(friend.isRecipeShareRequest, isFalse);

        final invite = SocialRequest.groupInvitation(
          fromUserId: 'a',
          toUserId: 'b',
          groupId: 'g',
          groupName: 'Sq',
          groupEmoji: 'X',
          fromUserName: 'A',
        );
        expect(invite.isRecipeShareRequest, isFalse);
      },
    );
  });

  group('serialization', () {
    test(
      'round-trips through Firestore map preserving recipeId/recipeTitle',
      () {
        final r = SocialRequest.recipeShareRequest(
          fromUserId: 'a',
          toUserId: 'b',
          recipeId: 'r1',
          recipeTitle: 'Pannkakor',
        );
        final back = SocialRequest.fromMap(r.id, r.toFirestore());
        expect(back.type, SocialRequestType.recipeShareRequest);
        expect(back.recipeId, 'r1');
        expect(back.recipeTitle, 'Pannkakor');
      },
    );

    test('toFirestore omits recipe fields for a friend request', () {
      // Mirrors the existing group-field omission test.
      // Protects against someone changing the conditional to always emit the
      // keys, which would pollute friend-request documents.
      final r = SocialRequest.friendRequest(fromUserId: 'a', toUserId: 'b');
      final payload = r.toFirestore();
      expect(payload.containsKey('recipeId'), isFalse);
      expect(payload.containsKey('recipeTitle'), isFalse);
    });
  });

  group('copyWith', () {
    // This is the Phase 2 accept-flow contract: when the recipient accepts or
    // rejects a recipe-share request, the service calls copyWith(status: ...).
    // The recipeId/recipeTitle must survive that status transition so downstream
    // code can still read which recipe was being requested.
    test('status change preserves recipeId and recipeTitle', () {
      final pending = SocialRequest.recipeShareRequest(
        fromUserId: 'a',
        toUserId: 'b',
        recipeId: 'r42',
        recipeTitle: 'Köttbullar',
      );
      final accepted = pending.copyWith(status: SocialRequestStatus.accepted);

      expect(accepted.recipeId, 'r42');
      expect(accepted.recipeTitle, 'Köttbullar');
      expect(accepted.status, SocialRequestStatus.accepted);
      // Type must also survive
      expect(accepted.type, SocialRequestType.recipeShareRequest);
    });
  });
}
