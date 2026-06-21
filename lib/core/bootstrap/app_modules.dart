/// Shared DI module + bootstrap-stage construction, used by both the consumer
/// entry point (`lib/main.dart`) and the admin dashboard entry point
/// (`lib/admin_main.dart`). Kept in one place so the two entry points can never
/// drift on which services exist.

import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/bootstrap/stages/bootstrap_stage.dart';

import 'package:butlery/core/bootstrap/stages/platform_stage.dart';
import 'package:butlery/core/bootstrap/stages/core_stage.dart';
import 'package:butlery/core/bootstrap/stages/content_stage.dart';
import 'package:butlery/core/bootstrap/stages/social_stage.dart';
import 'package:butlery/core/bootstrap/stages/ui_stage.dart';

import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/performance_module.dart';
import 'package:butlery/core/di/modules/ui_module.dart';
import 'package:butlery/core/di/modules/search_module.dart';
import 'package:butlery/core/di/modules/tagging_module.dart';
import 'package:butlery/core/di/modules/pantry_module.dart';

import 'package:butlery/core/utils/logger.dart';

/// DI modules in dependency order.
List<DIModule> buildDiModules() => [
      CoreModule(),
      SearchModule(),
      TaggingModule(),
      PantryModule(),
      ContentModule(),
      SocialModule(),
      MessagingModule(),
      CollaborationModule(),
      PerformanceModule(),
      UIModule(),
    ];

/// Bootstrap stages in run order.
List<BootstrapStage> buildBootstrapStages() => [
      PlatformStage(),
      CoreStage(),
      ContentStage(),
      SocialStage(),
      UIStage(),
    ];

/// BUT-431 cold-start: opt the consumer entry point into deferring the two
/// non-critical init side-effects (perf-monitoring start + Firestore ingredient
/// enrich) out of the pre-`runApp` path. Call this BEFORE bootstrap so the
/// eager paths skip them, then call [runDeferredBootstrap] from a post-frame
/// callback after `runApp`. Registration/`configure()` is never deferred, so
/// nothing can become unregistered. The admin entry point skips both calls and
/// keeps the eager behavior.
void enableDeferredBootstrap() {
  PerformanceModule.deferInitSideEffects = true;
  ContentStage.deferIngredientEnrich = true;
}

/// Runs the deferred init side-effects after the first frame. Each is wrapped
/// so a failure can't crash the app — both are non-critical and idempotent.
Future<void> runDeferredBootstrap() async {
  try {
    await PerformanceModule.runInitSideEffects();
  } catch (e) {
    AppLogger.warning('Deferred performance init failed: $e');
  }

  try {
    await ContentStage.enrichIngredientRegistry();
  } catch (e) {
    AppLogger.warning('Deferred ingredient enrich failed: $e');
  }
}
