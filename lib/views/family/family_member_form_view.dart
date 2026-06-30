import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/family/min_familj_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Add or edit a non-account family member, with the two-tier GDPR consent UX:
/// a required guardian consent for a minor (Art. 6) and a *separate, optional*
/// explicit consent for allergen health data (Art. 9), plus one-tap withdrawal.
class FamilyMemberFormView extends StatefulWidget {
  final DinerProfile? existing;

  const FamilyMemberFormView({super.key, this.existing});

  @override
  State<FamilyMemberFormView> createState() => _FamilyMemberFormViewState();
}

class _FamilyMemberFormViewState extends State<FamilyMemberFormView> {
  static const _palette = <String>[
    '#3E6F8E',
    '#7A5C8E',
    '#B07A3C',
    '#4A7C59',
    '#8B5A3C',
    '#C44536',
  ];

  late final MinFamiljViewModel _vm;
  late final TextEditingController _name;
  late String _color;
  late DinerAgeBand _band;
  late bool _guardianConsent;
  late bool _allergenConsent;
  late Set<String> _allergens;

  bool get _isEdit => widget.existing != null;
  bool get _isMinor => _band.isMinor;
  bool get _hasAllergens => _allergens.isNotEmpty;

  bool get _canSave {
    if (_name.text.trim().isEmpty) return false;
    if (_isMinor && !_guardianConsent) return false;
    if (_hasAllergens && !_allergenConsent) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _vm = MinFamiljViewModel()..load();
    final e = widget.existing;
    _name = TextEditingController(text: (e?.name).orEmpty())
      ..addListener(() => setState(() {}));
    _color = e?.avatarColor ?? _palette.first;
    _band = e?.ageBand ?? DinerAgeBand.child;
    _allergens = {...?e?.allergenPreferences?.trackedAllergens};
    // Never pre-ticked for a new member; reflects the stored state on edit.
    _guardianConsent = e?.guardianConsent != null;
    _allergenConsent = e?.hasAllergenConsent ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_vm.householdId == null) {
      await _vm.load();
    }
    final ok = await _vm.saveFamilyMember(
      existing: widget.existing,
      name: _name.text,
      ageBand: _band,
      avatarColor: _color,
      guardianConsentGiven: _guardianConsent,
      allergenConsentGiven: _allergenConsent,
      allergenKeys: _allergens,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _withdraw() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await _vm.withdrawAllergenConsent(e);
    if (ok && mounted) {
      setState(() {
        _allergens = {};
        _allergenConsent = false;
      });
    }
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.familyDeleteConfirmTitle,
          message: l10n.familyDeleteConfirmBody,
          confirmText: l10n.commonDelete,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !mounted) return;
    final ok = await _vm.deleteFamilyMember(e.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AdaptiveAppBar(
            title: _isEdit ? l10n.familyEditTitle : l10n.familyAddTitle,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StyledInput(
                      label: l10n.familyNameLabel,
                      hint: l10n.familyNameHint,
                      helperText: l10n.familyNameHint,
                      controller: _name,
                    ),
                    const SizedBox(height: AppDimensions.spacingL),
                    _colorPicker(context),
                    const SizedBox(height: AppDimensions.spacingL),
                    _ageBandPicker(context),
                    const SizedBox(height: AppDimensions.spacingL),
                    if (_isMinor) _guardianConsentCard(context),
                    _allergenCard(context),
                    if (_isEdit && widget.existing?.guardianConsent != null)
                      _consentGivenInfo(context),
                    const SizedBox(height: AppDimensions.spacingL),
                    if (_vm.hasError) _errorBox(context),
                    ActionButtons.primaryButton(
                      context,
                      label: l10n.commonSave,
                      icon: Icons.save,
                      isExpanded: true,
                      isLoading: _vm.isLoading,
                      onPressed: _canSave ? _save : null,
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: AppDimensions.spacingM),
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.familyDeleteMember),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fieldLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _colorPicker(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, l10n.familyColorLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, hex) in _palette.indexed)
              Semantics(
                button: true,
                selected: _color == hex,
                label: l10n.a11yColorSwatch(index + 1),
                child: GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: parseAvatarColor(hex),
                      border: Border.all(
                        color: _color == hex
                            ? cs.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _ageBandPicker(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, l10n.familyAgeBandLabel),
        Row(
          children: [
            for (final band in DinerAgeBand.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Semantics(
                    button: true,
                    selected: _band == band,
                    label: ageBandLabel(l10n, band),
                    child: GestureDetector(
                      onTap: () => setState(() => _band = band),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _band == band ? cs.primary : cs.surface,
                          border: Border.all(
                            color: _band == band
                                ? cs.primary
                                : cs.outlineVariant,
                          ),
                        ),
                        child: Text(
                          ageBandLabel(l10n, band),
                          style: AppTextStyles.captionText.copyWith(
                            color: _band == band ? Colors.white : cs.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
          child: Text(
            l10n.familyAgeBandHint,
            style: AppTextStyles.captionText.copyWith(
              color: cs.outline,
            ),
          ),
        ),
      ],
    );
  }

  /// The name to show in a consent sentence — the typed/edited name, or a
  /// neutral fallback so the sentence stays grammatical before the field is
  /// filled (save is gated on a non-empty name anyway).
  String _consentName({required bool minorContext}) {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    final l10n = context.l10n;
    return minorContext
        ? l10n.familyConsentChildWord
        : l10n.familyConsentPersonWord;
  }

  Widget _consentHeader(
    String title,
    String badge,
    Color badgeColor, {
    Color? titleColor,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: AppTextStyles.titleSmall.copyWith(color: titleColor),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: badgeColor)),
        child: Text(
          badge,
          style: AppTextStyles.captionText.copyWith(color: badgeColor),
        ),
      ),
    ],
  );

  Widget _guardianConsentCard(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingL),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: cs.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _consentHeader(
            l10n.familyConsentSectionTitle,
            l10n.familyConsentRequiredBadge,
            cs.primary,
            titleColor: cs.primary,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _guardianConsent,
            onChanged: (v) => setState(() => _guardianConsent = v ?? false),
            title: Text(
              l10n.familyGuardianConsentText(
                _consentName(minorContext: true),
              ),
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allergenCard(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final showWithdraw =
        _isEdit && (widget.existing?.hasAllergenConsent ?? false);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingL),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: context.butleryColors.warning, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _consentHeader(
            l10n.familyAllergenSectionTitle,
            l10n.familyOptionalBadge,
            cs.outline,
            titleColor: cs.secondary,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            l10n.familyAllergenHealthNote,
            style: AppTextStyles.captionText.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _allergenConsent,
            onChanged: (v) => setState(() {
              _allergenConsent = v ?? false;
              if (!_allergenConsent) _allergens = {};
            }),
            title: Text(
              l10n.familyAllergenConsentText(
                _consentName(minorContext: false),
              ),
              style: AppTextStyles.bodySmall,
            ),
          ),
          if (_allergenConsent) ...[
            const SizedBox(height: AppDimensions.spacingS),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in AllergenPreferenceOptions.allergens.entries)
                  _allergenChip(context, entry.key, entry.value),
              ],
            ),
          ],
          // Withdraw sits inside the amber card so it's clearly the control
          // that erases the allergen data shown above (consent-clarity).
          if (showWithdraw)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _withdraw,
                icon: const Icon(Icons.undo, size: 16),
                label: Text(l10n.familyWithdrawAllergenConsent),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _allergenChip(BuildContext context, String key, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _allergens.contains(key);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() {
          if (selected) {
            _allergens.remove(key);
          } else {
            _allergens.add(key);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.error.withValues(alpha: 0.1) : cs.surface,
            border: Border.all(
              color: selected ? cs.error : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionText.copyWith(
              color: selected ? cs.error : cs.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _consentGivenInfo(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final consent = widget.existing!.guardianConsent!;
    final d = consent.at;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: context.butleryColors.heroPaleGreen,
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.familyConsentGivenPrefix} $date · ${consent.consentVersion}',
                  style: AppTextStyles.captionText.copyWith(
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBox(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
    child: Text(
      (_vm.error).orEmpty(),
      style: AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
