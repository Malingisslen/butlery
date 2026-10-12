// lib/views/more/account_sign_in_methods_view.dart
//
// Inloggningssätt under Konto & säkerhet: what the account signs in with,
// and adding or taking away Google, Apple and a password (BUT-916 slice B,
// mockup screens 5 and 6).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account_sign_in_methods_viewmodel.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/views/more/sign_in_method_dialogs.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

class AccountSignInMethodsView extends StatefulWidget {
  const AccountSignInMethodsView({super.key});

  @override
  State<AccountSignInMethodsView> createState() =>
      _AccountSignInMethodsViewState();
}

class _AccountSignInMethodsViewState extends State<AccountSignInMethodsView> {
  final _viewModel = AccountSignInMethodsViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _failed() {
    final reason = _viewModel.error;
    if (reason == null || !mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    SnackBarUtils.showFailure(context, what: reason);
  }

  Future<void> _link(SignInProvider provider) async {
    final l10n = context.l10n;
    final name = AuthProviderFlows.providerName(provider);
    if (!await _confirmItIsYou()) return;
    if (!await _viewModel.link(provider)) return _failed();
    if (!mounted) return;
    SnackBarUtils.showSuccess(context, l10n.signInMethodsLinked(name));
  }

  Future<void> _unlink(SignInProvider provider) async {
    final l10n = context.l10n;
    final name = AuthProviderFlows.providerName(provider);
    final others = [
      for (final other in SignInProvider.values)
        if (other != provider && _viewModel.isLinked(other))
          AuthProviderFlows.providerName(other),
    ];
    final instead = _viewModel.hasPassword
        ? l10n.signInMethodsInsteadPassword
        : others.isEmpty
        ? ''
        : l10n.signInMethodsInsteadProvider(others.first);
    final apple = provider == SignInProvider.apple;
    final tail = !apple
        ? ''
        : _viewModel.appleRevokesHere
        ? l10n.signInMethodsUnlinkAppleAsks
        : l10n.signInMethodsUnlinkAppleYourself;
    final sure = await confirmUnlink(
      context,
      title: l10n.signInMethodsUnlinkTitle(name),
      message: [
        l10n.signInMethodsUnlinkBody(name),
        instead,
        tail,
      ].where((part) => part.isNotEmpty).join(' '),
    );
    if (!sure || !mounted) return;
    // Apple's own sheet gives the code that lets the app ask Apple to drop
    // the link; closing it leaves everything as it was.
    if (!await _confirmItIsYou(
      through: apple && _viewModel.appleRevokesHere
          ? SignInProvider.apple
          : null,
    )) {
      return;
    }
    if (!await _viewModel.unlink(provider)) return _failed();
    if (!mounted) return;
    SnackBarUtils.showSuccess(context, l10n.signInMethodsUnlinked(name));
  }

  /// Changing how the account signs in needs a fresh sign-in, so a borrowed
  /// unlocked phone cannot link its own Google account and lock the owner out.
  Future<bool> _confirmItIsYou({SignInProvider? through}) async {
    final confirmed = await AuthActionHandler.reauthenticate(
      context,
      through: through,
      onError: (reason) => SnackBarUtils.showFailure(context, what: reason),
    );
    return confirmed && mounted;
  }

  Future<void> _setPassword() async {
    final l10n = context.l10n;
    final password = await showSetPasswordDialog(
      context,
      email: _viewModel.passwordEmail.orEmpty(),
    );
    if (password == null || !mounted) return;
    if (!await _confirmItIsYou()) return;
    if (!await _viewModel.addPassword(password)) return _failed();
    if (!mounted) return;
    SnackBarUtils.showSuccess(context, l10n.signInMethodsPasswordSet);
  }

  Widget _providerRow(SignInProvider provider) {
    final l10n = context.l10n;
    final name = AuthProviderFlows.providerName(provider);
    if (!_viewModel.isLinked(provider)) {
      return ButleryListRow(
        label: name,
        subtitle: l10n.signInMethodsNotLinked,
        value: l10n.signInMethodsLink,
        onTap: () => _link(provider),
      );
    }
    final email = _viewModel.emailOf(provider);
    if (!_viewModel.canUnlink) {
      return ButleryListRow.info(
        label: name,
        value: email ?? l10n.signInMethodsOn,
      );
    }
    return ButleryListRow(
      label: name,
      subtitle: email,
      value: l10n.signInMethodsUnlink,
      onTap: () => _unlink(provider),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.space12),
    child: Text(
      text,
      style: AppTextStyles.captionBase.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MoreAreaScaffold.backTo(
      l10n.settingsAccountAreaTitle,
      title: l10n.settingsSignInMethodsTitle,
      sections: [
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final only = _viewModel.onlyProvider;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ButleryListSection(
                  rows: [
                    if (_viewModel.hasPassword)
                      ButleryListRow.info(
                        label: l10n.signInMethodsPassword,
                        value: l10n.signInMethodsOn,
                      )
                    else
                      ButleryListRow(
                        label: l10n.signInMethodsPassword,
                        value: l10n.signInMethodsSetPassword,
                        onTap: _viewModel.canAddPassword
                            ? _setPassword
                            : () => _failedNoAddress(),
                      ),
                    for (final provider in SignInProvider.values)
                      if (_viewModel.isLinked(provider) ||
                          _viewModel.isOffered(provider))
                        _providerRow(provider),
                  ],
                ),
                _note(
                  only == null
                      ? l10n.signInMethodsLastOne
                      : l10n.signInMethodsOnlyProvider(
                          AuthProviderFlows.providerName(only),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _failedNoAddress() => SnackBarUtils.showFailure(
    context,
    what: context.l10n.signInMethodsNoAddress,
  );
}
