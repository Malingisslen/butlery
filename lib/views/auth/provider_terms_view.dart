import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/auth/provider_terms_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/styled/field_error_line.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// "Välkommen till Butlery" (BUT-916 mockup screen 2): the name the account
/// will show, prefilled from Google or Apple, and the terms. AuthWrapper
/// shows it while `UserService.termsPending` holds, so it comes back after a
/// restart until it is answered (C1, C3).
class ProviderTermsView extends StatefulWidget {
  const ProviderTermsView({super.key, this.viewModel});

  @visibleForTesting
  final ProviderTermsViewModel? viewModel;

  @override
  State<ProviderTermsView> createState() => _ProviderTermsViewState();
}

class _ProviderTermsViewState extends State<ProviderTermsView> {
  late final ProviderTermsViewModel _vm =
      widget.viewModel ?? ProviderTermsViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _vm,
    child: const _ProviderTermsContent(),
  );
}

class _ProviderTermsContent extends StatefulWidget {
  const _ProviderTermsContent();

  @override
  State<_ProviderTermsContent> createState() => _ProviderTermsContentState();
}

class _ProviderTermsContentState extends State<_ProviderTermsContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: context.read<ProviderTermsViewModel>().initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create(ProviderTermsViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await vm.accept(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProviderTermsViewModel>();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final body = AppTextStyles.bodySmall.copyWith(color: cs.onSurface);
    final link = AppTextStyles.bodySmall.copyWith(
      color: context.modeColors.textLink,
      decoration: TextDecoration.underline,
      decorationColor: context.modeColors.textLink,
    );
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: ButleryPageBody(
          width: PageWidth.compact,
          child: SingleChildScrollView(
            padding: ButleryPageBody.margin(
              context,
              top: AppDimensions.space32,
              bottom: AppDimensions.space24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.providerTermsTitle,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    l10n.providerTermsSubtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space32),
                  LabeledField(
                    label: l10n.authYourName,
                    child: TextFormField(
                      key: const ValueKey('providerTerms.name'),
                      controller: _name,
                      enabled: !vm.isLoading,
                      style: fieldTextStyle(context, enabled: !vm.isLoading),
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.givenName],
                      validator: FormValidators.authName(),
                      errorBuilder: FieldErrorLine.builder,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    l10n.providerTermsNameHelp,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The words beside the box are its screen-reader stop.
                      ExcludeSemantics(
                        child: ButleryCheckbox(
                          key: const ValueKey('providerTerms.accept'),
                          value: vm.termsAccepted,
                          onChanged: vm.isLoading ? null : vm.setTermsAccepted,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space8),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Semantics(
                              checked: vm.termsAccepted,
                              child: GestureDetector(
                                onTap: vm.isLoading
                                    ? null
                                    : () => vm.setTermsAccepted(
                                        !vm.termsAccepted,
                                      ),
                                child: Text(
                                  l10n.authTermsAcceptPrefix,
                                  style: body,
                                ),
                              ),
                            ),
                            ButleryLink(
                              semanticLabel: l10n.a11yTermsOfServiceLink,
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.termsOfService,
                              ),
                              child: Text(l10n.authTermsOfService, style: link),
                            ),
                            Text(l10n.authTermsAcceptMiddle, style: body),
                            ButleryLink(
                              semanticLabel: l10n.a11yPrivacyPolicyLink,
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.privacyPolicy,
                              ),
                              child: Text(
                                l10n.profilePrivacyPolicy,
                                style: link,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (vm.error != null) ...[
                    const SizedBox(height: AppDimensions.space8),
                    FieldErrorLine(vm.error!),
                  ],
                  const SizedBox(height: AppDimensions.space24),
                  HeroButton(
                    key: const ValueKey('providerTerms.create'),
                    label: l10n.authCreateAccount,
                    onPressed: vm.canCreate ? () => _create(vm) : null,
                    busy: vm.isLoading,
                    expand: true,
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  ButleryTextButton(
                    key: const ValueKey('providerTerms.decline'),
                    label: vm.shownAgain
                        ? l10n.providerTermsCancelAndDelete
                        : l10n.commonCancel,
                    onPressed: vm.isLoading ? null : vm.decline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
