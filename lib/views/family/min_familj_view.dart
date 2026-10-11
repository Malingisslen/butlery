import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/min_familj_viewmodel.dart';
import 'package:butlery/views/family/family_member_form_view.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/views/family/household_portions_sheet.dart';
import 'package:butlery/views/settings/widgets/household_allergen_filter_tile.dart';
import 'package:butlery/views/settings/widgets/household_allergen_sharing_tile.dart';
import 'package:butlery/views/settings/widgets/meal_allergen_scope_tile.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// "Familj & hushåll": who the household is, how many portions recipes open
/// with, and how allergies apply to everyone (Mer, omtänkt del 2).
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
      appBar: ButleryTopBar.undersida(
        title: l10n.familyTitle,
        backTo: l10n.moreTitle,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: vm.isLoading
          // The plate line says what it fetches (produktregler.md:163).
          ? StateWidget.loading(message: l10n.loadingFamily)
          : (vm.hasError && vm.householdId == null)
          ? StateWidget.error(
              message: vm.error!,
              onAction: () => vm.load(),
            )
          : SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: EdgeInsetsDirectional.only(
                      start: ButleryTopBar.sideMargin(context),
                      end: ButleryTopBar.sideMargin(context),
                      bottom: AppDimensions.spacingLg,
                    ),
                    children: [
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        l10n.familyIntro,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      _accountsSection(vm, l10n),
                      _familySection(context, vm, l10n),
                      ButleryListSection(
                        title: l10n.familyMealsSection,
                        rows: const [_PortionsRow()],
                      ),
                      const _HouseholdAllergenSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Accounts and family members share one list so the two sections are
  // told apart from each other too.
  List<String> _initials(MinFamiljViewModel vm) => distinctInitials([
    for (final a in vm.accounts) a.displayName,
    for (final p in vm.familyMembers) p.name,
  ]);

  Widget _accountsSection(MinFamiljViewModel vm, AppLocalizations l10n) {
    final initials = _initials(vm);
    return ButleryListSection(
      title: l10n.familyAccountsSection,
      rows: [
        for (var i = 0; i < vm.accounts.length; i++)
          FamilyAccountRow(
            member: vm.accounts[i],
            isAdmin: vm.isAdmin(vm.accounts[i].memberId),
            isCurrentUser: vm.isCurrentUser(vm.accounts[i].memberId),
            initials: initials[i],
          ),
      ],
    );
  }

  Widget _familySection(
    BuildContext context,
    MinFamiljViewModel vm,
    AppLocalizations l10n,
  ) {
    final initials = _initials(vm);
    return ButleryListSection(
      title: l10n.familyProfilesSection,
      rows: [
        for (var i = 0; i < vm.familyMembers.length; i++)
          FamilyMemberRow(
            profile: vm.familyMembers[i],
            onTap: () => _openForm(context, existing: vm.familyMembers[i]),
            initials: initials[vm.accounts.length + i],
          ),
        ButleryListRow(
          label: l10n.familyAddMemberRow,
          leading: ButleryIcons.plus,
          onTap: () => _openForm(context),
        ),
      ],
    );
  }
}

/// The default portions, read from the profile and redrawn when a save in
/// the sheet lands.
class _PortionsRow extends StatefulWidget {
  const _PortionsRow();

  @override
  State<_PortionsRow> createState() => _PortionsRowState();
}

class _PortionsRowState extends State<_PortionsRow> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _userService.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    _userService.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = _userService.currentUserProfile?.householdSize;
    return ButleryListRow(
      label: l10n.householdPortionsTitle,
      value: size?.toString() ?? l10n.householdSizeRecipeDefault,
      onTap: () => showHouseholdPortionsSheet(context),
    );
  }
}

/// The three household allergen switches, shown only to someone with a
/// household. Each switch still hides itself while it does not apply, so the
/// second and third draw their own divider.
class _HouseholdAllergenSection extends StatefulWidget {
  const _HouseholdAllergenSection();

  @override
  State<_HouseholdAllergenSection> createState() =>
      _HouseholdAllergenSectionState();
}

class _HouseholdAllergenSectionState extends State<_HouseholdAllergenSection> {
  HouseholdService? _householdService;

  @override
  void initState() {
    super.initState();
    _householdService = ServiceLocator.tryGet<HouseholdService>();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_householdService?.hasHousehold ?? false)) {
      return const SizedBox.shrink();
    }
    return ButleryListSection(
      title: context.l10n.familyAllergiesSection,
      rows: const [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BUT-1465, BUT-2362, BUT-1693.
            HouseholdAllergenFilterTile(),
            MealAllergenScopeTile(dividerAbove: true),
            HouseholdAllergenSharingTile(dividerAbove: true),
          ],
        ),
      ],
    );
  }
}
