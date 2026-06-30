import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/min_familj_viewmodel.dart';
import 'package:butlery/views/family/family_member_form_view.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// "Min familj" — manage the household's account holders and the non-account
/// family members (children + guests represented as [DinerProfile]s).
class MinFamiljView extends StatelessWidget {
  const MinFamiljView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MinFamiljViewModel()..load(),
      child: const _MinFamiljContent(),
    );
  }
}

class _MinFamiljContent extends StatelessWidget {
  const _MinFamiljContent();

  Future<void> _openForm(
    BuildContext context, {
    DinerProfile? existing,
  }) async {
    final vm = context.read<MinFamiljViewModel>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FamilyMemberFormView(existing: existing),
      ),
    );
    if (saved == true && context.mounted) {
      await vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<MinFamiljViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AdaptiveAppBar(title: l10n.familyTitle),
      body: vm.isLoading
          ? StateWidget.loading()
          : (vm.hasError && vm.householdId == null)
          ? StateWidget.error(
              message: vm.error!,
              onAction: () => vm.load(),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.familyIntro,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingL),
                      _accountsSection(context, vm, l10n),
                      const SizedBox(height: AppDimensions.spacingXl),
                      _familySection(context, vm, l10n),
                      const SizedBox(height: AppDimensions.spacingXl),
                      ActionButtons.secondaryButton(
                        context,
                        label: l10n.familyAddMember,
                        icon: Icons.add,
                        isExpanded: true,
                        onPressed: () => _openForm(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _accountsSection(
    BuildContext context,
    MinFamiljViewModel vm,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FamilySectionHeader(
          title: l10n.familyHouseholdSection,
          trailing: '${vm.accounts.length} ${l10n.familyAccountsWord}',
        ),
        const SizedBox(height: AppDimensions.spacingS),
        for (final account in vm.accounts)
          FamilyAccountRow(
            member: account,
            isAdmin: vm.isAdmin(account.memberId),
          ),
      ],
    );
  }

  Widget _familySection(
    BuildContext context,
    MinFamiljViewModel vm,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FamilySectionHeader(
          title: l10n.familyMembersSection,
          trailing: '${vm.familyMembers.length} ${l10n.familyProfilesWord}',
        ),
        const SizedBox(height: AppDimensions.spacingS),
        if (vm.familyMembers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingL,
            ),
            child: Text(
              l10n.familyEmptySubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final profile in vm.familyMembers)
            FamilyMemberRow(
              profile: profile,
              onTap: () => _openForm(context, existing: profile),
            ),
      ],
    );
  }
}
