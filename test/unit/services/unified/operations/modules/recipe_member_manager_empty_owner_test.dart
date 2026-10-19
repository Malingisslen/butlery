/// BUT-2107: a collaborative recipe whose `socialData.ownerId` is '' and whose
/// `createdBy` is the signed-in user is that user's own recipe.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid that matches nobody: the creator lost the owner's rights and the
/// owner-protection checks guarded a uid nobody has.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/modules/recipe_member_manager.dart';

import '../../../../../test_support/base_unit_test.dart';

const _me = 'user_me';
const _other = 'user_other';
const _stranger = 'user_stranger';
const _group = 'g1';

void main() {
  late List<Recipe> written;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() => written = []);

  Recipe recipe({
    String? createdBy = _me,
    String ownerId = '',
    bool allowMemberInvites = false,
    Map<String, ResourcePermission>? members,
    Map<String, List<String>>? grants,
    List<String>? categoryIds,
  }) => Recipe(
    core: RecipeCore(
      id: 'r1',
      title: 'Gryta',
      description: 'd',
      ingredients: const ['i'],
      instructions: const ['s'],
      mealType: 'Middag',
      createdBy: createdBy,
      createdAt: DateTime(2026, 10, 8),
      updatedAt: DateTime(2026, 10, 8),
    ),
    type: RecipeType.collaborative,
    socialData: RecipeSocialData(
      ownerId: ownerId,
      allowMemberInvites: allowMemberInvites,
      memberPermissions:
          members ??
          {
            _me: ResourcePermission.owner,
            _other: ResourcePermission.editor,
          },
      grants: grants,
      categoryIds: categoryIds,
    ),
  );

  RecipeMemberManager managerFor(Recipe r, {String? uid = _me}) =>
      RecipeMemberManager(
        getCurrentUserId: () => uid,
        getCurrentUserDisplayName: () => 'Me',
        getRecipes: () => [r],
        updateRecipe: (updated) async {
          written.add(updated);
          return true;
        },
        notificationService: null,
      );

  group('removeMember', () {
    test(
      'the creator is protected from removal when ownerId is empty',
      () async {
        final ok = await managerFor(recipe()).removeMember(
          recipeId: 'r1',
          memberId: _me,
        );

        expect(ok, isFalse);
        expect(written, isEmpty);
      },
    );

    test('the creator can still remove another member', () async {
      final ok = await managerFor(recipe()).removeMember(
        recipeId: 'r1',
        memberId: _other,
      );

      expect(ok, isTrue);
      final perms = written.single.socialData!.memberPermissions!;
      expect(perms.keys, [_me]);
    });

    test(
      'closing: someone else created it and I hold no admin right',
      () async {
        final ok = await managerFor(recipe(createdBy: _stranger)).removeMember(
          recipeId: 'r1',
          memberId: _other,
        );

        expect(ok, isFalse);
        expect(written, isEmpty);
      },
    );

    test(
      'closing: no owner can be worked out and I hold no admin right',
      () async {
        final ok = await managerFor(recipe(createdBy: null)).removeMember(
          recipeId: 'r1',
          memberId: _other,
        );

        expect(ok, isFalse);
        expect(written, isEmpty);
      },
    );
  });

  group('updateMemberPermission', () {
    test('the creator cannot be downgraded when ownerId is empty', () async {
      final ok = await managerFor(recipe()).updateMemberPermission(
        recipeId: 'r1',
        memberId: _me,
        newPermission: ResourcePermission.viewer,
      );

      expect(ok, isFalse);
      expect(written, isEmpty);
    });

    test('the creator can still change another member', () async {
      final ok = await managerFor(recipe()).updateMemberPermission(
        recipeId: 'r1',
        memberId: _other,
        newPermission: ResourcePermission.viewer,
      );

      expect(ok, isTrue);
      expect(
        written.single.socialData!.memberPermissions![_other],
        ResourcePermission.viewer,
      );
    });

    test(
      'closing: someone else created it and I hold no admin right',
      () async {
        final ok = await managerFor(recipe(createdBy: _stranger))
            .updateMemberPermission(
              recipeId: 'r1',
              memberId: _other,
              newPermission: ResourcePermission.viewer,
            );

        expect(ok, isFalse);
        expect(written, isEmpty);
      },
    );
  });

  group('addMember', () {
    test('the creator may invite when ownerId is empty', () async {
      final ok = await managerFor(recipe()).addMember(
        recipeId: 'r1',
        memberId: 'user_new',
        memberDisplayName: 'Ny',
      );

      expect(ok, isTrue);
      expect(
        written.single.socialData!.memberPermissions,
        contains('user_new'),
      );
    });

    test('closing: invites are closed and I am an editor on another '
        "person's recipe", () async {
      final ok =
          await managerFor(
            recipe(
              createdBy: _stranger,
              members: {_me: ResourcePermission.editor},
            ),
          ).addMember(
            recipeId: 'r1',
            memberId: 'user_new',
            memberDisplayName: 'Ny',
          );

      expect(ok, isFalse);
      expect(written, isEmpty);
    });
  });

  group('removeGroup', () {
    final token = RecipeSocialData.groupGrant(_group);

    test('the creator keeps their key when ownerId is empty', () async {
      final ok = await managerFor(
        recipe(
          grants: {
            _me: [token],
            _other: [token],
          },
          categoryIds: [_group],
        ),
      ).removeGroup(recipeId: 'r1', groupId: _group);

      expect(ok, isTrue);
      final perms = written.single.socialData!.memberPermissions!;
      expect(perms.keys, [_me]);
    });

    test('closing: with no resolvable owner the key is cut like anyone '
        "else's", () async {
      final ok = await managerFor(
        recipe(
          createdBy: null,
          members: {
            _me: ResourcePermission.admin,
            _other: ResourcePermission.editor,
          },
          grants: {
            _me: [token],
            _other: [token],
          },
          categoryIds: [_group],
        ),
      ).removeGroup(recipeId: 'r1', groupId: _group);

      expect(ok, isTrue);
      expect(written.single.socialData!.memberPermissions!, isEmpty);
    });
  });

  group('getRecipeMembers', () {
    test('the owner row names the creator when ownerId is empty', () async {
      final members = await managerFor(recipe()).getRecipeMembers('r1');

      expect(members.first['userId'], _me);
      expect(members.first['isOwner'], isTrue);
      expect(members.where((m) => m['userId'] == _me), hasLength(1));
      expect(members.map((m) => m['userId']), isNot(contains('')));
    });

    test('closing: no owner row when the owner cannot be worked out', () async {
      final members = await managerFor(
        recipe(createdBy: null, members: {_other: ResourcePermission.editor}),
      ).getRecipeMembers('r1');

      expect(members.map((m) => m['userId']), [_other]);
      expect(members.any((m) => m['isOwner'] == true), isFalse);
    });
  });
}
