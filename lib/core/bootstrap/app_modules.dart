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
