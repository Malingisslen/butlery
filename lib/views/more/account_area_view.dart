// lib/views/more/account_area_view.dart
//
// Konto & säkerhet under Mer: signing in, and what ends a session or an
// account (Mer, omtänkt, 2026-10-10). Each sign-in row opens its own page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth_service.dart';
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
  static final _unchanging = ValueNotifier<void>(null);

  UserService? _userService;
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.tryGet<UserService>();
    _authService = ServiceLocator.tryGet<AuthService>();
  }

  /// "E-post, Google, Apple": the ways the account signs in with.
  String _signInMethodsSummary(AppLocalizations l10n) {
    final auth = _authService;
    return [
      if (auth?.hasPasswordSignIn ?? true) l10n.signInMethodsEmailName,
      for (final provider in SignInProvider.values)
        if (auth?.isProviderLinked(provider) ?? false)
          AuthProviderFlows.providerName(provider),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void open(String route) => Navigator.pushNamed(context, route);
    // The page under this one links and unlinks sign-in methods, which
    // changes the summary and whether the password row is shown.
    return ListenableBuilder(
      listenable: _authService ?? _unchanging,
      builder: (context, _) => _page(context, l10n, open),
    );
  }

  Widget _page(
    BuildContext context,
    AppLocalizations l10n,
    void Function(String route) open,
  ) {
    return MoreAreaScaffold(
      title: l10n.settingsAccountAreaTitle,
      sections: [
        ButleryListSection(
          title: l10n.settingsSignInSection,
          rows: [
            ButleryListRow(
              label: l10n.settingsSignInMethodsTitle,
              value: _signInMethodsSummary(l10n),
              onTap: () => open(Routes.settingsAccountSignInMethods),
            ),
            ButleryListRow(
              label: l10n.settingsAccountEmail,
              value: _userService?.currentUserProfile?.email,
              onTap: () => open(Routes.settingsAccountEmail),
            ),
            // An account made with Google or Apple has no password to
            // change (BUT-916 C7).
            if (_authService?.hasPasswordSignIn ?? true)
              ButleryListRow(
                label: l10n.settingsAccountPassword,
                onTap: () => open(Routes.settingsAccountPassword),
              ),
            ButleryListRow(
              label: l10n.settingsAccountTwoStep,
              onTap: () => open(Routes.settingsAccountTwoStep),
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
