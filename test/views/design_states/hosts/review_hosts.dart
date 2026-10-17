/// Hosts for the views the screen register had not yet compared with a
/// sketch frame, so each can be pumped and photographed.
library;

import '../state_host.dart';
import 'review_hosts_a.dart';
import 'review_hosts_account.dart';
import 'review_hosts_b.dart';
import 'review_hosts_c.dart';
import 'review_hosts_admin.dart';
import 'review_hosts_auth.dart';
import 'review_hosts_import.dart';
import 'review_hosts_misc.dart';
import 'review_hosts_recipes.dart';
import 'review_hosts_settings.dart';
import 'review_hosts_social.dart';
import 'review_hosts_social2.dart';

final Map<String, StateHost> reviewHosts = {
  ...reviewAHosts,
  ...reviewBHosts,
  ...reviewCHosts,
  ...reviewAccountHosts,
  ...reviewAdminHosts,
  ...reviewAuthHosts,
  ...reviewImportHosts,
  ...reviewMiscHosts,
  ...reviewRecipeHosts,
  ...reviewSettingsHosts,
  ...reviewSocialHosts,
  ...reviewSocial2Hosts,
};
