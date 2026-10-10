// lib/views/more/account_area_view.dart
//
// Konto & säkerhet under Mer: signing in, and what ends a session or an
// account (Mer, omtänkt, 2026-10-10). The three sign-in rows open today's
// Kontosäkerhet page until it is split into one page per form.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

class AccountAreaView extends StatefulWidget {
  const AccountAreaView({super.key});

  @override
  State<AccountAreaView> createState() => _AccountAreaViewState();
}

class _AccountAreaViewState extends State<AccountAreaView> {
  UserService? _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.tryGet<UserService>();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void openSecurity() =>
        Navigator.pushNamed(context, Routes.settingsAccountSecurity);
    return MoreAreaScaffold(
      title: l10n.settingsAccountAreaTitle,
      sections: [
        ButleryListSection(
          title: l10n.settingsSignInSection,
          rows: [
            ButleryListRow(
              label: l10n.settingsAccountEmail,
              value: _userService?.currentUserProfile?.email,
              onTap: openSecurity,
            ),
            ButleryListRow(
              label: l10n.settingsAccountPassword,
              onTap: openSecurity,
            ),
            ButleryListRow(
              label: l10n.settingsAccountTwoStep,
              onTap: openSecurity,
            ),
          ],
        ),
        ButleryListSection(
          rows: [
            ButleryListRow(
              label: l10n.profileLogout,
              leading: ButleryIcons.logOut,
              onTap: () => AuthActionHandler.handleLogout(context),
            ),
          ],
        ),
        ButleryListSection(
          rows: [
            // Last on the page; the deletion dialog says what happens.
            ButleryListRow.danger(
              label: l10n.profileDeleteAccount,
              onTap: () => AuthActionHandler.handleDeleteAccount(context),
            ),
          ],
        ),
      ],
    );
  }
}
