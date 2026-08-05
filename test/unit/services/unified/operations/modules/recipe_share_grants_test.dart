// test/unit/services/unified/operations/modules/recipe_share_grants_test.dart
//
// BUT-1797: the grant algebra behind "un-share this group".
//
// Every case below is one of Malin's decisions of 2026-08-03, or the invariant
// that keeps those decisions safe: `memberPermissions` is the only thing that
// decides access, so a bug here must never leave someone in `grants` who is not
// in `memberPermissions`.
//
// The reverse is NORMAL and deliberate, not a bug — the owner sits in
// `memberPermissions` with no grant, because access from ownership needs no
// reason recorded. (An earlier version of this comment claimed the invariant
// held both ways; it never did, and almost every fixture here disproves it.)

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/modules/recipe_share_grants.dart';

void main() {
  group('RecipeShareGrants.revokeGroup', () {
    const owner = 'owner_1';
    const groupId = 'family';
    final groupToken = RecipeSocialData.groupGrant(groupId);

    test(
      'removes a member whose only reason to be here was that group',
      () {
        final result = RecipeShareGrants.revokeGroup(
          grants: {
            'anna': [groupToken],
          },
          permissions: {
            owner: ResourcePermission.admin,
            'anna': ResourcePermission.editor,
          },
          groupId: groupId,
          ownerId: owner,
        );

        expect(result.permissions!.containsKey('anna'), isFalse);
        expect(result.grants!.containsKey('anna'), isFalse);
        expect(result.removedMemberIds, ['anna']);
        expect(result.retainedMemberIds, isEmpty);
        expect(
          result.permissions![owner],
          ResourcePermission.admin,
          reason: 'the owner is untouched by a group revoke',
        );
      },
    );

    test(
      'THE DECIDED CASE: a member who also has a direct share keeps access',
      () {
        // Malin, 2026-08-03: two separate decisions were made about this person.
        // Revoking the group undoes exactly one of them.
        final result = RecipeShareGrants.revokeGroup(
          grants: {
            'bea': [groupToken, RecipeSocialData.directGrant],
          },
          permissions: {
            owner: ResourcePermission.admin,
            'bea': ResourcePermission.editor,
          },
          groupId: groupId,
          ownerId: owner,
        );

        expect(result.permissions!['bea'], ResourcePermission.editor);
        expect(result.grants!['bea'], [RecipeSocialData.directGrant]);
        expect(result.removedMemberIds, isEmpty);
        expect(result.retainedMemberIds, ['bea']);
      },
    );

    test('a member in two groups keeps access when one is revoked', () {
      final otherToken = RecipeSocialData.groupGrant('work');

      final result = RecipeShareGrants.revokeGroup(
        grants: {
          'cilla': [groupToken, otherToken],
        },
        permissions: {
          owner: ResourcePermission.admin,
          'cilla': ResourcePermission.viewer,
        },
        groupId: groupId,
        ownerId: owner,
      );

      expect(result.permissions!['cilla'], ResourcePermission.viewer);
      expect(result.grants!['cilla'], [otherToken]);
      expect(result.retainedMemberIds, ['cilla']);
    });

    test('members of an untouched group are not affected', () {
      final otherToken = RecipeSocialData.groupGrant('work');

      final result = RecipeShareGrants.revokeGroup(
        grants: {
          'anna': [groupToken],
          'david': [otherToken],
        },
        permissions: {
          owner: ResourcePermission.admin,
          'anna': ResourcePermission.editor,
          'david': ResourcePermission.editor,
        },
        groupId: groupId,
        ownerId: owner,
      );

      expect(result.permissions!['david'], ResourcePermission.editor);
      expect(result.grants!['david'], [otherToken]);
      expect(result.removedMemberIds, ['anna']);
    });

    test('a member with no grants entry at all is never cut', () {
      // Replaces a vacuous test that asserted the ABSENCE of a uid present in
      // neither input map. `revokeGroup` is a pure filter over those two maps,
      // so it cannot invent a key and no mutation could have reddened it.
      //
      // This is the load-bearing version of the same worry: `erik` holds a
      // permission with no recorded reason. A rewrite that walks `permissions`
      // and treats "no recorded reason" as group-only cuts him, and this is the
      // only test that reddens on it. (A rewrite that walks `permissions` but
      // still requires the token to be present skips him and stays green — so
      // the claim is about that specific mutant, not about every rewrite.)
      //
      // (The snapshot property it used to claim belongs to the SHARE path, which
      // resolves group members at share time. It is genuinely proven in
      // social_recipe_sharing_service_test.dart, not here — revokeGroup takes no
      // group roster and could not consult one even in principle.)
      final result = RecipeShareGrants.revokeGroup(
        grants: {
          'anna': [groupToken],
        },
        permissions: {
          owner: ResourcePermission.admin,
          'anna': ResourcePermission.editor,
          'erik': ResourcePermission.viewer,
        },
        groupId: groupId,
        ownerId: owner,
      );

      expect(result.permissions!['erik'], ResourcePermission.viewer);
      expect(result.removedMemberIds, ['anna']);
    });

    test('the owner is never cut, even holding only a group grant', () {
      final result = RecipeShareGrants.revokeGroup(
        grants: {
          owner: [groupToken],
        },
        permissions: {owner: ResourcePermission.admin},
        groupId: groupId,
        ownerId: owner,
      );

      expect(result.permissions![owner], ResourcePermission.admin);
      expect(result.removedMemberIds, isEmpty);
      expect(result.retainedMemberIds, [owner]);
      // The asymmetry: the owner keeps the permission and LOSES the spent grant.
      // Untested, this was free to flip either way.
      expect(result.grants!.containsKey(owner), isFalse);
    });

    test('a recipe with no grants loses only the label, and does not throw', () {
      // Deliberately NOT read as "everyone is direct". The field is written from
      // the start; the only documents without it are test data.
      final result = RecipeShareGrants.revokeGroup(
        grants: null,
        permissions: {
          owner: ResourcePermission.admin,
          'anna': ResourcePermission.editor,
        },
        groupId: groupId,
        ownerId: owner,
      );

      expect(result.permissions!['anna'], ResourcePermission.editor);
      expect(result.removedMemberIds, isEmpty);
      expect(result.grants, isNull, reason: 'absent stays absent');
    });

    test('does not mutate the maps it was given', () {
      final grants = {
        'anna': [groupToken],
      };
      final permissions = {
        owner: ResourcePermission.admin,
        'anna': ResourcePermission.editor,
      };

      RecipeShareGrants.revokeGroup(
        grants: grants,
        permissions: permissions,
        groupId: groupId,
        ownerId: owner,
      );

      expect(grants['anna'], [groupToken]);
      expect(permissions['anna'], ResourcePermission.editor);
    });
  });

  group('RecipeShareGrants.add / dropMember', () {
    test('re-sharing by the same route does not stack the grant', () {
      // Otherwise one revoke would leave a duplicate behind and the member would
      // keep access for a reason the user believes they already withdrew.
      var grants = RecipeShareGrants.add(
        null,
        'anna',
        RecipeSocialData.directGrant,
      );
      grants = RecipeShareGrants.add(
        grants,
        'anna',
        RecipeSocialData.directGrant,
      );

      expect(grants['anna'], [RecipeSocialData.directGrant]);
    });

    test('a second, different route is recorded alongside the first', () {
      var grants = RecipeShareGrants.add(
        null,
        'anna',
        RecipeSocialData.directGrant,
      );
      grants = RecipeShareGrants.add(
        grants,
        'anna',
        RecipeSocialData.groupGrant('family'),
      );

      expect(grants['anna'], [
        RecipeSocialData.directGrant,
        RecipeSocialData.groupGrant('family'),
      ]);
    });

    test(
      'an explicit removal drops every grant, including group ones',
      () {
        // Item 4 of the plan: a direct removal cuts a member who also holds a
        // group grant. Leaving the group grant behind would make a later
        // group-revoke look like it had already run.
        final grants = RecipeShareGrants.dropMember({
          'anna': [
            RecipeSocialData.directGrant,
            RecipeSocialData.groupGrant('family'),
          ],
          'bea': [RecipeSocialData.directGrant],
        }, 'anna');

        expect(grants!.containsKey('anna'), isFalse);
        expect(grants['bea'], [RecipeSocialData.directGrant]);
      },
    );

    test('dropMember on a recipe with no grants stays null', () {
      expect(RecipeShareGrants.dropMember(null, 'anna'), isNull);
    });
  });

  group('RecipeShareGrants.forShare', () {
    test('nothing to record returns NULL, not an empty map', () {
      // The rule its sibling `mergeCategoryIds` follows. Two shapes for one fact
      // is the drift this codebase has already paid for once, and `copyWith`'s
      // sentinel means null and `{}` are indistinguishable downstream — so only
      // a direct test can hold this line to the rule.
      expect(
        RecipeShareGrants.forShare(existing: null, userIds: const []),
        isNull,
      );
    });

    test('a plain share records direct, and keeps what was already there', () {
      final grants = RecipeShareGrants.forShare(
        existing: {
          'mom': [RecipeSocialData.groupGrant('family')],
        },
        userIds: const ['anna'],
      );

      expect(grants!['anna'], [RecipeSocialData.directGrant]);
      expect(grants['mom'], [RecipeSocialData.groupGrant('family')]);
    });

    test('excludeUserId keeps the sharer out of their own share', () {
      final grants = RecipeShareGrants.forShare(
        existing: null,
        userIds: const ['me', 'anna'],
        excludeUserId: 'me',
      );

      expect(grants!.containsKey('me'), isFalse);
      // Control: the loop ran, so 'me' is absent because it was skipped.
      expect(grants['anna'], [RecipeSocialData.directGrant]);
    });
  });

  group('RecipeShareGrants.mergeCategoryIds', () {
    // The panel renders one revoke row per entry here, so anything that lands
    // in this list and matches no member's grant is a button that reports
    // success while cutting nobody. The per-test comment below says which token
    // separates which guard.
    test('neither refusal can be removed without this reddening', () {
      // The two guards are separate lines and need separate inputs. A 'direct'
      // token cannot tell them apart: 'group:' and 'direct' are both SIX
      // characters, so `substring(6)` is '' either way and whichever guard
      // survives still catches it. 'direct-share' is the discriminator — it
      // fails startsWith and its remainder is NOT empty, so only the startsWith
      // guard can refuse it.
      final merged = RecipeShareGrants.mergeCategoryIds(null, {
        'anna': [
          RecipeSocialData.groupGrant(''),
          'direct-share',
          // Shorter than the prefix. No current producer can emit it, but it is
          // the only input that catches `substring` being hoisted ABOVE guard 1:
          // that mutant leaves the other two tokens green and throws RangeError.
          'own',
          RecipeSocialData.groupGrant('family'),
        ],
      });

      expect(
        merged,
        ['family'],
        reason:
            "'family' is the control — it proves the loop ran, so the empty "
            'id is missing because it was refused, not because nothing merged',
      );
    });

    // Both halves are pinned by the test above. The caller-level test in
    // social_recipe_sharing_service_test.dart pins that the input is REACHABLE
    // through the public `grantsByUserId` parameter — not that either guard
    // works, which its 'direct' fixture cannot distinguish.

    test('the groups already on the recipe survive a later share', () {
      // `RecipeSocialData.copyWith` reads an explicit null as "erase", so a
      // caller passing only the new share's groups would silently drop every
      // earlier row from the panel.
      final merged = RecipeShareGrants.mergeCategoryIds(
        ['grp-old'],
        {
          'anna': [RecipeSocialData.groupGrant('grp-new')],
        },
      );

      expect(merged, containsAll(['grp-old', 'grp-new']));
      expect(merged, hasLength(2), reason: 'deduped set, not a concat');
    });

    test('nothing to record leaves the field NULL, not empty', () {
      // Returning `{}` here would write an empty list where the create path
      // writes null — two shapes for one fact, which is the drift this codebase
      // has paid for before. (`toJson` emits the key either way; the distinction
      // is null vs `[]`, not present vs absent.)
      expect(RecipeShareGrants.mergeCategoryIds(null, null), isNull);
    });
  });
}
