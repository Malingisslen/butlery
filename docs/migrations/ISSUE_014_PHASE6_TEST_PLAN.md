# Issue #014 Phase 6: Comprehensive Testing Plan

**Status**: Ready for Execution
**Estimated Time**: 24-32 hours
**Dependencies**: Phases 1-5 Complete ✅
**Priority**: HIGH - Required before production migration

---

## Overview

Phase 6 focuses on comprehensive testing of the Issue #014 migration from array-based to subcollection-based status tracking. This phase ensures production readiness through unit tests, integration tests, and performance validation.

### Success Criteria
- ✅ Zero test failures in `flutter test`
- ✅ All subcollection CRUD operations tested
- ✅ Migration script validated in staging environment
- ✅ Performance benchmarks meet SLA (<500ms for 100+ member queries)
- ✅ Security rules tested with unauthorized access attempts
- ✅ Integration tests verify end-to-end sharing workflows

---

## Phase 6.1: Fix Existing Test Errors (8-12 hours)

### Current State
- **200+ test errors** in test/ directory due to removed model methods
- Errors caused by calls to deprecated methods: `.isViewedBy()`, `.isDismissedBy()`, `.sharedToUserIds`

### Fix Strategy

#### A. Repository Test Fixes (4 hours)
**Files to Fix** (~50 errors):
- `test/unit/repositories/firebase_shared_recipe_repository_test.dart`
- `test/unit/repositories/firebase_shared_menu_repository_test.dart`
- `test/unit/repositories/firebase_shared_shopping_repository_test.dart`
- `test/unit/repositories/base_shared_content_repository_test.dart`

**Fix Pattern**:
```dart
// OLD: Testing removed model methods
expect(recipe.isViewedBy(userId), true);
expect(recipe.sharedToUserIds, contains(userId));

// NEW: Test repository subcollection methods
final hasViewed = await repository.hasViewed(recipeId, userId);
expect(hasViewed, true);

final isMember = await repository.isMember(recipeId, userId);
expect(isMember, true);
```

**Action Items**:
1. Replace `.isViewedBy()` calls with `await repository.hasViewed()`
2. Replace `.sharedToUserIds` access with `await repository.getMembers()`
3. Replace `.isDismissedBy()` calls with `await repository.hasDismissed()`
4. Update test setup to create subcollection documents instead of arrays
5. Verify FakeFirestore supports subcollection queries

#### B. Service Test Fixes (3 hours)
**Files to Fix** (~40 errors):
- `test/unit/services/unified/unified_recipe_service_test.dart`
- `test/unit/services/unified/unified_menu_service_test.dart`
- `test/unit/services/unified/unified_shopping_service_test.dart`
- `test/unit/services/unified/modules/social_recipe/social_recipe_sharing_service_test.dart`

**Fix Pattern**:
```dart
// OLD: Missing recipientIds parameter
await service.shareWithFriends(recipeId, friendIds);

// NEW: Pass recipientIds separately
await repository.createSharedRecipe(
  sharedRecipe,
  recipientIds: friendIds,
);
```

**Action Items**:
1. Update all service test mocks to require `recipientIds` parameter
2. Remove expectations for model methods (`.isViewedBy()`, etc.)
3. Add expectations for repository subcollection calls
4. Update test data factories to create models without arrays

#### C. ViewModel Test Fixes (3 hours)
**Files to Fix** (~60 errors):
- `test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart`
- `test/unit/viewmodels/shared_content/shared_menu_viewmodel_test.dart`
- `test/unit/viewmodels/shared_content/shared_shopping_viewmodel_test.dart`

**Fix Pattern**:
```dart
// OLD: Testing removed model methods in ViewModel
expect(viewModel.isRecipeViewed(recipe), false);
// Expected recipe.isViewedBy() to be called

// NEW: Test ViewModel cache instead
await viewModel.loadSharedRecipes();
expect(viewModel.isRecipeViewed(recipe), true);
// Expects cache populated from repository.hasViewed()
```

**Action Items**:
1. Update ViewModel tests to expect subcollection repository calls
2. Test status caching logic (Map<String, bool> caches)
3. Verify cache invalidation on status updates
4. Test synchronous cache access methods

#### D. Widget Test Fixes (2 hours)
**Files to Fix** (~50 errors):
- `test/widget/social/shared_content_lists_test.dart`
- `test/widget/social/shared_recipe_card_test.dart`
- Widget tests calling model status methods

**Fix Pattern**:
```dart
// OLD: Widget tests expect model methods
expect(find.text('Viewed'), findsOneWidget);
// Depends on recipe.isViewedBy()

// NEW: Widget tests use ViewModel cache
await tester.pumpWidget(
  ChangeNotifierProvider.value(
    value: mockViewModel,
    child: SharedRecipeCard(recipe: recipe),
  ),
);
when(mockViewModel.isRecipeViewed(recipe)).thenReturn(true);
expect(find.text('Viewed'), findsOneWidget);
```

**Action Items**:
1. Mock ViewModel cache methods instead of model methods
2. Update widget test setup to provide ViewModels
3. Test UI updates when status changes in cache

---

## Phase 6.2: New Subcollection Tests (6-8 hours)

### A. Repository Subcollection CRUD Tests (3 hours)

#### Test File: `test/unit/repositories/firebase_shared_content_repository_subcollections_test.dart`

**Test Coverage**:
```dart
group('Subcollection - Members', () {
  test('addMember() creates document in members subcollection', () async {
    // Arrange
    final recipeId = 'recipe_123';
    final userId = 'user_456';

    // Act
    await repository.addMember(recipeId, userId, addedBy: 'owner_789');

    // Assert
    final memberDoc = await firestore
        .collection('shared_recipes')
        .doc(recipeId)
        .collection('members')
        .doc(userId)
        .get();

    expect(memberDoc.exists, true);
    expect(memberDoc.data()!['userId'], userId);
    expect(memberDoc.data()!['addedBy'], 'owner_789');
    expect(memberDoc.data()!['role'], 'member');
  });

  test('isMember() returns true for existing member', () async {
    // Arrange
    await repository.addMember('recipe_123', 'user_456', addedBy: 'owner');

    // Act
    final isMember = await repository.isMember('recipe_123', 'user_456');

    // Assert
    expect(isMember, true);
  });

  test('isMember() returns false for non-member', () async {
    // Act
    final isMember = await repository.isMember('recipe_123', 'user_999');

    // Assert
    expect(isMember, false);
  });

  test('getMembers() returns all member documents', () async {
    // Arrange
    await repository.addMember('recipe_123', 'user_1', addedBy: 'owner');
    await repository.addMember('recipe_123', 'user_2', addedBy: 'owner');
    await repository.addMember('recipe_123', 'user_3', addedBy: 'owner');

    // Act
    final members = await repository.getMembers('recipe_123');

    // Assert
    expect(members.length, 3);
    expect(members.map((m) => m['userId']), containsAll(['user_1', 'user_2', 'user_3']));
  });

  test('removeMember() deletes member document', () async {
    // Arrange
    await repository.addMember('recipe_123', 'user_456', addedBy: 'owner');

    // Act
    await repository.removeMember('recipe_123', 'user_456');

    // Assert
    final isMember = await repository.isMember('recipe_123', 'user_456');
    expect(isMember, false);
  });
});

group('Subcollection - Views', () {
  test('addView() creates document in views subcollection', () async {
    // Test view recording
  });

  test('hasViewed() returns true for viewed content', () async {
    // Test viewed status check
  });

  test('getViewCount() returns correct count', () async {
    // Test view count aggregation
  });
});

group('Subcollection - Engagements', () {
  test('addEngagement() creates document with action type', () async {
    // Test engagement recording (import/join)
  });

  test('hasEngaged() returns true for engaged user', () async {
    // Test engagement status check
  });

  test('getEngagementCount() returns correct count', () async {
    // Test engagement count aggregation
  });
});

group('Subcollection - Dismissals', () {
  test('addDismissal() creates dismissal document', () async {
    // Test dismissal recording
  });

  test('hasDismissed() returns true for dismissed content', () async {
    // Test dismissal status check
  });

  test('removeDismissal() allows undismiss', () async {
    // Test undismiss functionality
  });
});

group('Subcollection - Collaborators', () {
  test('addCollaborator() creates collaborator document', () async {
    // Test collaborator addition
  });

  test('removeCollaborator() removes collaborator', () async {
    // Test collaborator removal
  });

  test('getActiveCollaborators() returns online collaborators', () async {
    // Test realtime collaborator tracking
  });
});
```

### B. Query Performance Tests (2 hours)

#### Test File: `test/performance/subcollection_query_performance_test.dart`

**Test Coverage**:
```dart
group('Subcollection Query Performance', () {
  test('getMembers() completes in <500ms for 100 members', () async {
    // Arrange: Create 100 member documents
    final recipeId = 'recipe_performance_test';
    for (int i = 0; i < 100; i++) {
      await repository.addMember(recipeId, 'user_$i', addedBy: 'owner');
    }

    // Act + Measure
    final stopwatch = Stopwatch()..start();
    final members = await repository.getMembers(recipeId);
    stopwatch.stop();

    // Assert
    expect(members.length, 100);
    expect(stopwatch.elapsedMilliseconds, lessThan(500),
        reason: 'Query took ${stopwatch.elapsedMilliseconds}ms (SLA: <500ms)');
  });

  test('isMember() completes in <200ms (indexed query)', () async {
    // Test indexed member lookup performance
  });

  test('getSharedContentForUserViaSubcollection() completes in <1000ms for 1000 shared items', () async {
    // Test collectionGroup query performance at scale
  });

  test('hasViewed() completes in <200ms (indexed query)', () async {
    // Test viewed status lookup performance
  });
});
```

### C. Migration Script Tests (3 hours)

#### Test File: `test/integration/migration/issue_014_migration_test.dart`

**Test Coverage**:
```dart
group('Issue #014 Migration Script', () {
  test('Dry-run mode does not modify data', () async {
    // Arrange: Create shared recipe with arrays
    await createTestRecipeWithArrays();

    // Act: Run migration in dry-run mode
    final migrator = DataMigrator(firestore, dryRun: true);
    await migrator.migrateCollection('shared_recipes');

    // Assert: Arrays still exist, no subcollections created
    final recipe = await getSharedRecipe('test_recipe');
    expect(recipe.data()!.containsKey('sharedToUserIds'), true);

    final membersSnapshot = await firestore
        .collection('shared_recipes')
        .doc('test_recipe')
        .collection('members')
        .get();
    expect(membersSnapshot.docs.isEmpty, true);
  });

  test('Migration creates subcollection documents from arrays', () async {
    // Arrange
    await createRecipeWithArrays(
      id: 'recipe_1',
      sharedToUserIds: ['user_1', 'user_2', 'user_3'],
      viewedByUserIds: ['user_1'],
      engagedByUserIds: ['user_2'],
      dismissedByUserIds: ['user_3'],
    );

    // Act
    final migrator = DataMigrator(firestore, dryRun: false);
    await migrator.migrateCollection('shared_recipes');

    // Assert: Subcollections created
    final membersSnapshot = await firestore
        .collection('shared_recipes')
        .doc('recipe_1')
        .collection('members')
        .get();
    expect(membersSnapshot.docs.length, 3);

    final viewsSnapshot = await firestore
        .collection('shared_recipes')
        .doc('recipe_1')
        .collection('views')
        .get();
    expect(viewsSnapshot.docs.length, 1);
  });

  test('Migration updates count fields correctly', () async {
    // Arrange
    await createRecipeWithArrays(
      id: 'recipe_2',
      viewedByUserIds: ['user_1', 'user_2', 'user_3'],
      engagedByUserIds: ['user_1', 'user_2'],
      dismissedByUserIds: ['user_3'],
    );

    // Act
    final migrator = DataMigrator(firestore, dryRun: false);
    await migrator.migrateCollection('shared_recipes');

    // Assert: Count fields updated
    final recipe = await getSharedRecipe('recipe_2');
    expect(recipe.data()!['viewCount'], 3);
    expect(recipe.data()!['engagementCount'], 2);
    expect(recipe.data()!['dismissalCount'], 1);
  });

  test('Migration is idempotent - safe to run multiple times', () async {
    // Arrange
    await createRecipeWithArrays(
      id: 'recipe_3',
      sharedToUserIds: ['user_1'],
    );

    // Act: Run migration twice
    final migrator = DataMigrator(firestore, dryRun: false);
    await migrator.migrateCollection('shared_recipes');
    await migrator.migrateCollection('shared_recipes'); // Run again

    // Assert: No duplicates, no errors
    final membersSnapshot = await firestore
        .collection('shared_recipes')
        .doc('recipe_3')
        .collection('members')
        .get();
    expect(membersSnapshot.docs.length, 1); // Still 1, not 2
  });

  test('Migration preserves original arrays for rollback', () async {
    // Arrange
    final originalArrays = ['user_1', 'user_2', 'user_3'];
    await createRecipeWithArrays(
      id: 'recipe_4',
      sharedToUserIds: originalArrays,
    );

    // Act
    final migrator = DataMigrator(firestore, dryRun: false);
    await migrator.migrateCollection('shared_recipes');

    // Assert: Arrays still present (non-destructive)
    final recipe = await getSharedRecipe('recipe_4');
    expect(recipe.data()!['sharedToUserIds'], originalArrays);
  });

  test('Migration handles all 3 collections', () async {
    // Test: shared_recipes, shared_menus, shared_shopping_lists
  });

  test('Migration handles empty arrays gracefully', () async {
    // Test: Documents with no arrays
  });

  test('Migration skips already-migrated documents', () async {
    // Test: Documents without arrays are skipped
  });
});
```

---

## Phase 6.3: Integration Tests (4-6 hours)

### A. End-to-End Sharing Workflow Tests (3 hours)

#### Test File: `test/integration/sharing/shared_content_workflow_test.dart`

**Test Coverage**:
```dart
group('Shared Recipe Workflow', () {
  test('Complete recipe sharing flow - create, view, import, dismiss', () async {
    // Arrange: Two users (sharer and recipient)
    final sharerUserId = 'user_sharer';
    final recipientUserId = 'user_recipient';

    // Act 1: User A shares recipe with User B
    final recipe = createTestRecipe(ownerId: sharerUserId);
    final sharedRecipeId = await sharedRecipeRepository.createSharedRecipe(
      SharedRecipe.create(
        sharedByUserId: sharerUserId,
        sharedByDisplayName: 'Anna Andersson',
        shareMessage: 'Test recipe',
        originalRecipeId: recipe.id,
        recipeSnapshot: recipe,
      ),
      recipientIds: [recipientUserId],
    );

    // Assert 1: Recipient appears in members subcollection
    final isMember = await sharedRecipeRepository.isMember(
      sharedRecipeId,
      recipientUserId,
    );
    expect(isMember, true);

    // Act 2: User B views shared recipe
    await sharedRecipeRepository.markAsViewed(sharedRecipeId, recipientUserId);

    // Assert 2: View recorded in subcollection
    final hasViewed = await sharedRecipeRepository.hasViewed(
      sharedRecipeId,
      recipientUserId,
    );
    expect(hasViewed, true);

    // Act 3: User B imports recipe
    await sharedRecipeRepository.markAsImported(sharedRecipeId, recipientUserId);

    // Assert 3: Engagement recorded
    final hasEngaged = await sharedRecipeRepository.hasEngaged(
      sharedRecipeId,
      recipientUserId,
    );
    expect(hasEngaged, true);

    // Act 4: User B dismisses recipe
    await sharedRecipeRepository.markAsDismissed(sharedRecipeId, recipientUserId);

    // Assert 4: Dismissal recorded
    final hasDismissed = await sharedRecipeRepository.hasDismissed(
      sharedRecipeId,
      recipientUserId,
    );
    expect(hasDismissed, true);

    // Act 5: User B undismisses recipe
    await sharedRecipeRepository.undismiss(sharedRecipeId, recipientUserId);

    // Assert 5: Dismissal removed
    final stillDismissed = await sharedRecipeRepository.hasDismissed(
      sharedRecipeId,
      recipientUserId,
    );
    expect(stillDismissed, false);
  });

  test('Share with 150+ users (beyond 100-element limit)', () async {
    // Arrange: Create 150 test users
    final recipientIds = List.generate(150, (i) => 'user_$i');

    // Act: Share recipe with all 150 users
    final sharedRecipeId = await sharedRecipeRepository.createSharedRecipe(
      createTestSharedRecipe(),
      recipientIds: recipientIds,
    );

    // Assert: All 150 members added to subcollection
    final members = await sharedRecipeRepository.getMembers(sharedRecipeId);
    expect(members.length, 150);

    // Assert: Old array limit would have failed (max 100)
    // This test proves unlimited sharing works
  });
});

group('ViewModel Status Caching', () {
  test('ViewModel caches status on load for synchronous UI access', () async {
    // Arrange
    final viewModel = SharedRecipeViewModel(
      repository: sharedRecipeRepository,
      authRepository: mockAuthRepository,
    );

    // Create shared recipe with viewed status
    final recipeId = await createSharedRecipeWithViews();
    await sharedRecipeRepository.markAsViewed(recipeId, currentUserId);

    // Act: Load recipes (should cache status)
    await viewModel.loadSharedRecipes();

    // Assert: Synchronous cache access works
    final recipe = viewModel.sharedRecipes.first;
    expect(viewModel.isRecipeViewed(recipe), true); // Synchronous!
  });

  test('ViewModel cache updates when status changes', () async {
    // Test cache invalidation on status updates
  });
});
```

### B. Permission Validation Tests (2 hours)

#### Test File: `test/integration/security/subcollection_permissions_test.dart`

**Test Coverage**:
```dart
group('Subcollection Permission Validation', () {
  test('Non-member cannot read members subcollection', () async {
    // Test unauthorized access is blocked
  });

  test('Member can read but not write members subcollection', () async {
    // Test read-only member permissions
  });

  test('Owner can add/remove members', () async {
    // Test owner permissions
  });

  test('User can record own view but not others', () async {
    // Test view recording permissions
  });

  test('User can dismiss/undismiss own entries only', () async {
    // Test dismissal privacy
  });
});
```

### C. Concurrent Access Tests (1 hour)

#### Test File: `test/integration/concurrency/subcollection_concurrency_test.dart`

**Test Coverage**:
```dart
group('Concurrent Subcollection Access', () {
  test('Multiple users can view simultaneously without conflicts', () async {
    // Test concurrent view recording
  });

  test('Multiple members can be added simultaneously', () async {
    // Test concurrent member additions
  });

  test('Subcollection operations do not cause array conflicts', () async {
    // Compare to old array-based approach (would fail)
  });
});
```

---

## Phase 6.4: Security Rules Testing (2-3 hours)

### Firestore Security Rules Test File

#### Test File: `firestore.rules.test.ts` (using Firebase Emulator)

**Test Coverage**:
```javascript
describe('Shared Recipes - Members Subcollection', () => {
  it('should allow owner to add members', async () => {
    const db = authedApp({ uid: 'owner_id' });
    await assertSucceeds(
      db.collection('shared_recipes/recipe_1/members')
        .doc('new_user')
        .set({
          userId: 'new_user',
          addedBy: 'owner_id',
          addedAt: firebase.firestore.FieldValue.serverTimestamp(),
          role: 'member',
        })
    );
  });

  it('should deny non-owner from adding members', async () => {
    const db = authedApp({ uid: 'random_user' });
    await assertFails(
      db.collection('shared_recipes/recipe_1/members')
        .doc('new_user')
        .set({
          userId: 'new_user',
          addedBy: 'random_user',
          addedAt: firebase.firestore.FieldValue.serverTimestamp(),
          role: 'member',
        })
    );
  });

  it('should allow member to remove themselves', async () => {
    const db = authedApp({ uid: 'member_id' });
    await assertSucceeds(
      db.collection('shared_recipes/recipe_1/members')
        .doc('member_id')
        .delete()
    );
  });

  it('should deny member from removing other members', async () => {
    const db = authedApp({ uid: 'member_1' });
    await assertFails(
      db.collection('shared_recipes/recipe_1/members')
        .doc('member_2')
        .delete()
    );
  });
});

describe('Shared Recipes - Views Subcollection', () => {
  it('should allow user to record own view', async () => {
    // Test view recording permissions
  });

  it('should deny user from recording others views', async () => {
    // Test view recording is restricted to self
  });
});

describe('Shared Recipes - Dismissals Subcollection', () => {
  it('should allow user to dismiss content', async () => {
    // Test dismissal creation
  });

  it('should allow user to undismiss (delete dismissal)', async () => {
    // Test dismissal removal
  });

  it('should deny user from viewing others dismissals', async () => {
    // Test dismissal privacy
  });
});
```

---

## Phase 6.5: Documentation & Reporting (2-3 hours)

### A. Test Coverage Report (1 hour)

Generate comprehensive test coverage report:

```bash
# Generate coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report
open coverage/html/index.html
```

**Coverage Targets**:
- Repository layer: >90% coverage
- Service layer: >85% coverage
- ViewModel layer: >80% coverage
- Subcollection methods: 100% coverage

### B. Performance Benchmark Report (1 hour)

#### Document: `docs/migrations/ISSUE_014_PERFORMANCE_REPORT.md`

**Contents**:
```markdown
# Issue #014 Performance Benchmark Report

## Query Performance

### Subcollection Query Benchmarks (Production-like data volume)

| Operation | Data Size | Old (Arrays) | New (Subcollections) | Improvement |
|-----------|-----------|--------------|----------------------|-------------|
| isMember() | 100 members | N/A (crashed) | 120ms | ∞ (array limit) |
| getMembers() | 100 members | N/A (limit 100) | 380ms | ∞ (unlimited) |
| hasViewed() | 500 views | 45ms (array scan) | 85ms (indexed) | -89% latency |
| getSharedContent() | 1000 items | 8500ms (array-in) | 1200ms (collectionGroup) | +708% faster |

### Scalability Tests

- ✅ **150-member sharing**: PASS (old system: FAIL at 100)
- ✅ **1000+ shared items**: 1.2s load time (old: 8.5s timeout)
- ✅ **Concurrent views**: No conflicts (old: array write conflicts)

### Memory Usage

- Subcollection queries: 2.1MB peak (old arrays: 3.8MB for 100 items)
- Cache overhead: +180KB for ViewModel status caching (acceptable)
```

### C. Migration Summary Document (1 hour)

#### Document: `docs/migrations/ISSUE_014_MIGRATION_SUMMARY.md`

**Contents**:
- Migration execution timeline
- Data integrity verification results
- Rollback plan validation
- Production deployment checklist
- Monitoring and alerting setup
- Known issues and workarounds

---

## Execution Timeline

### Week 1 (Days 1-2): Fix Existing Tests
- **Day 1**: Fix repository tests (4 hours)
- **Day 2 Morning**: Fix service tests (3 hours)
- **Day 2 Afternoon**: Fix ViewModel tests (3 hours)

### Week 1 (Days 3-4): New Subcollection Tests
- **Day 3 Morning**: Repository CRUD tests (3 hours)
- **Day 3 Afternoon**: Performance tests (2 hours)
- **Day 4**: Migration script tests (3 hours)

### Week 2 (Day 5): Integration & Security
- **Day 5 Morning**: End-to-end workflow tests (3 hours)
- **Day 5 Afternoon**: Security rules tests (2 hours)

### Week 2 (Day 6): Documentation & Reporting
- **Day 6 Morning**: Coverage report (1 hour)
- **Day 6 Afternoon**: Performance report (1 hour)
- **Day 6 End**: Migration summary (1 hour)

**Total Time**: 24-32 hours (depends on test complexity)

---

## Success Metrics

### Quantitative
- ✅ Zero test failures in `flutter test`
- ✅ >85% code coverage for new subcollection methods
- ✅ All performance SLAs met (<500ms for 100-member queries)
- ✅ Migration script completes without errors in staging

### Qualitative
- ✅ Tests clearly document subcollection behavior
- ✅ Performance report shows unlimited sharing works
- ✅ Security rules prevent unauthorized access
- ✅ Migration guide validated in staging environment

---

## Risk Mitigation

### Test Infrastructure Risks
**Risk**: FakeFirestore may not support subcollection queries
**Mitigation**: Use Firebase Emulator for integration tests if FakeFirestore insufficient

**Risk**: Performance tests may be unreliable in CI
**Mitigation**: Run performance tests locally with production-like data volume

**Risk**: Security rules testing requires Firebase Emulator
**Mitigation**: Set up Firebase Emulator in CI pipeline for automated testing

### Migration Risks
**Risk**: Migration script may fail on production data edge cases
**Mitigation**: Test with anonymized production data snapshot in staging

**Risk**: Performance degradation on large datasets
**Mitigation**: Run performance benchmarks with 1000+ items in staging

---

## Post-Phase 6 Checklist

Before marking Phase 6 complete:
- [ ] All test errors fixed (zero failures in `flutter test`)
- [ ] New subcollection tests written and passing
- [ ] Integration tests verify end-to-end workflows
- [ ] Security rules tested with Firebase Emulator
- [ ] Performance benchmarks documented and meet SLAs
- [ ] Migration script validated in staging environment
- [ ] Test coverage report generated (>85% target)
- [ ] Phase 6 completion documented in MASTERPLAN.md
- [ ] Production deployment approved by team

---

## Next Steps After Phase 6

Once Phase 6 is complete:
1. **Production Migration**: Execute migration script in production (see ISSUE_014_MIGRATION_GUIDE.md)
2. **Monitoring Setup**: Configure Firebase Performance Monitoring for subcollection queries
3. **User Communication**: Notify users about unlimited sharing capability (marketing opportunity!)
4. **Cleanup (Optional - Phase 7)**: Remove original arrays after 1-2 weeks of stable operation

---

## Support & Resources

**Documentation**:
- Migration Guide: `docs/migrations/ISSUE_014_MIGRATION_GUIDE.md`
- MASTERPLAN: `docs/ultimate/MASTERPLAN.md` (Issue #014 completion entry)
- Test Patterns: `docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md`

**Tools**:
- Migration Script: `tools/migrate_issue_014_arrays_to_subcollections.dart`
- Coverage Tool: `flutter test --coverage`
- Firebase Emulator: `firebase emulators:start`

**Contact**:
- Development Team: [team contact]
- Emergency Rollback: See ISSUE_014_MIGRATION_GUIDE.md Section "Rollback Procedure"
