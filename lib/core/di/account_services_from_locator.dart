import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/export/comment_reactions_export_manager.dart';
import 'package:butlery/services/account/export/compliance_export_manager.dart';
import 'package:butlery/services/account/export/erasure_residue_export_manager.dart';
import 'package:butlery/services/account/export/moderation_appeals_export_manager.dart';
import 'package:butlery/services/account/export/shared_residue_export_manager.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notif;
import 'package:butlery/services/offline_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_it/get_it.dart';

/// Builds the Art. 17 deletion service over [container].
///
/// NotificationService and OfflineService live in the user scope, which is
/// replaced at sign-in, so both are looked up when a deletion or sign-out runs
/// rather than when this is built.
AccountDeletionService buildAccountDeletionService(
  GetIt container,
  FirebaseFunctions functions,
) {
  return AccountDeletionService(
    authService: container<AuthService>(),
    functions: functions,
    offlineService: () => container.isRegistered<OfflineService>()
        ? container<OfflineService>()
        : null,
    resetNotificationsForLogout: () =>
        container<notif.NotificationService>().resetForLogout(),
  );
}

/// Builds the Art. 15/20 export over [container].
///
/// The household, diner and family-rating repositories are registered in the
/// user scope, which is replaced at every sign-in, while this service is
/// app-scoped. They are therefore passed as tear-offs looked up at each
/// export, never as instances: an instance kept here would export the previous
/// account's household after a switch on the same device.
DataExportService buildDataExportService(
  GetIt container,
  FirebaseFunctions functions,
) {
  return DataExportService(
    authRepository: container<AuthRepository>(),
    firestoreRepository: container<FirestoreRepository>(),
    dataExportRepository: container<FirebaseDataExportRepository>(),
    commentsRepository: container<CommentsRepository>(),
    ratingsRepository: container<RatingsRepository>(),
    feedbackRepository: container<FeedbackRepository>(),
    cookSnapRepository: container<CookSnapRepository>(),
    cookEventRepository: container<CookEventRepository>(),
    activityEventRepository: container<ActivityEventRepository>(),
    weeklyMenuPlanRepository: container<WeeklyMenuPlanRepository>(),
    groupWeeklyMenuPlanRepository: container<GroupWeeklyMenuPlanRepository>(),
    pantryRepository: container<PantryRepository>(),
    recipeRepository: container<RecipeRepository>(),
    personalTagRepository: container<FirebasePersonalTagRepository>(),
    personalTagGroupRepository: container<FirebasePersonalTagGroupRepository>(),
    households: container.get<HouseholdRepository>,
    dinerProfiles: container.get<DinerProfileRepository>,
    familyRatings: container.get<FamilyRatingRepository>,
    complianceExportManager: ComplianceExportManager(
      dataExportRepository: container<FirebaseDataExportRepository>(),
      authRepository: container<AuthRepository>(),
      functions: functions,
    ),
    sharedResidueExportManager: SharedResidueExportManager(
      functions: functions,
    ),
    erasureResidueExportManager: ErasureResidueExportManager(
      functions: functions,
    ),
    commentReactionsExportManager: CommentReactionsExportManager(
      functions: functions,
    ),
    moderationAppealsExportManager: ModerationAppealsExportManager(
      functions: functions,
    ),
  );
}
