import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/family/min_familj_viewmodel.dart';
import 'package:butlery/views/family/family_form_parts.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
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
  late final String _initialSnapshot;
  late String _color;
  late DinerAgeBand _band;
  late bool _guardianConsent;
  late bool _allergenConsent;
  late Set<String> _allergens;
  late Set<String> _dislikes;

  /// Common disliked ingredients offered as quick-pick chips. A soft
  /// meal-planning preference (not health data), so labels live here as plain
  /// data — the same pattern as [AllergenPreferenceOptions]. Keys are the
  /// lowercase Swedish token stored on the profile; values are the chip labels.
  static const Map<String, String> _dislikeOptions = {
    'svamp': 'Svamp',
    'lök': 'Lök',
    'vitlök': 'Vitlök',
    'oliver': 'Oliver',
    'koriander': 'Koriander',
    'tomat': 'Tomat',
    'paprika': 'Paprika',
    'aubergine': 'Aubergine',
    'rödbetor': 'Rödbetor',
    'blåmögelost': 'Blåmögelost',
    'lever': 'Lever',
    'inlagd sill': 'Inlagd sill',
    'chili': 'Chili',
    'russin': 'Russin',
  };

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
    _dislikes = {...?e?.dislikedIngredients};
    // Never pre-ticked for a new member; reflects the stored state on edit.
    _guardianConsent = e?.guardianConsent != null;
    _allergenConsent = e?.hasAllergenConsent ?? false;
    _initialSnapshot = _snapshot();
  }

  String _snapshot() => [
    _name.text.trim(),
    _color,
    _band.name,
    _guardianConsent,
    _allergenConsent,
    ([..._allergens]..sort()).join(','),
    ([..._dislikes]..sort()).join(','),
  ].join('|');

  bool get _dirty => _snapshot() != _initialSnapshot;

  Future<void> _confirmLeave() async {
    final discard = await CommonDialogActions.showUnsavedChangesConfirmation(
      context: context,
    );
    if (discard == true && mounted) Navigator.of(context).pop();
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
      dislikedKeys: _dislikes,
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
          confirmText: l10n.familyDeleteMember,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !mounted) return;
    final ok = await _vm.deleteFamilyMember(e.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: ButleryPage.undersida(
            // A subpage of Mitt hushåll (Komponentark v1:71-78). A form is a
            // focus mode, so the tab bar is not drawn (B-54).
            title: _isEdit ? l10n.familyEditTitle : l10n.familyAddTitle,
            backTo: l10n.familyTitle,
            showTabBar: false,
            // Spara and Ta bort stand fixed at the foot, as the sketch draws.
            bottomNavigationBar: _footer(context),
            // Top, not Center: a scroll view under loose constraints is only
            // as tall as a short form, and Center then pushed the form down
            // and left an empty band under the top bar (BUT-2261).
            body: SingleChildScrollView(
              padding: ButleryPageBody.margin(
                context,
                top: AppDimensions.space16,
                bottom: AppDimensions.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StyledInput(
                    label: l10n.familyNameLabel.toUpperCase(),
                    hint: l10n.familyNameHint,
                    controller: _name,
                  ),
                  const SizedBox(height: AppDimensions.space16),
                  _colorPicker(context),
                  const SizedBox(height: AppDimensions.space16),
                  _ageBandPicker(context),
                  const SizedBox(height: AppDimensions.space16),
                  if (_isMinor) _guardianConsentSection(context),
                  _allergenSection(context),
                  _dislikesSection(context),
                  if (_isEdit && widget.existing?.guardianConsent != null)
                    _consentGivenInfo(context),
                  if (_vm.hasError) _errorBox(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: ButleryPageBody.margin(
          context,
          top: AppDimensions.space8,
          bottom: AppDimensions.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ActionButtons.primaryButton(
              context,
              label: l10n.commonSave,
              isExpanded: true,
              isLoading: _vm.isLoading,
              onPressed: _canSave ? _save : null,
            ),
            if (_isEdit)
              ButleryTextButton(
                onPressed: _delete,
                label: l10n.familyDeleteMember,
                tone: ButleryTextButtonTone.danger,
              ),
          ],
        ),
      ),
    );
  }

  Widget _colorPicker(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(l10n.familyColorLabel),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final (index, hex) in _palette.indexed)
              Semantics(
                button: true,
                selected: _color == hex,
                label: l10n.a11yColorSwatch(index + 1),
                child: GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  // The ring stands off the swatch, so the picked one reads
                  // as picked without hiding its colour.
                  child: Container(
                    width: AppDimensions.minTouchTarget,
                    height: AppDimensions.minTouchTarget,
                    padding: const EdgeInsets.all(AppDimensions.space4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _color == hex
                            ? cs.onSurface
                            : Colors.transparent,
                        width: AppDimensions.borderWidthThick,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusControl,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: parseAvatarColor(context, hex),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.space8,
                        ),
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
        FormFieldLabel(l10n.familyAgeBandLabel),
        FormTabs<DinerAgeBand>(
          values: DinerAgeBand.values.reversed.toList(),
          selected: _band,
          labelOf: (band) => ageBandLabel(l10n, band),
          onSelected: (band) => setState(() => _band = band),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space8),
          child: Text(
            l10n.familyAgeBandHint,
            style: AppTextStyles.captionText.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space16),
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

  Widget _guardianConsentSection(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      title: l10n.familyConsentSectionTitle,
      badge: l10n.familyConsentRequiredBadge,
      children: [
        FormCheckRow(
          label: l10n.familyGuardianConsentText(
            _consentName(minorContext: true),
          ),
          value: _guardianConsent,
          onChanged: (v) => setState(() => _guardianConsent = v),
          bodyStyle: true,
        ),
      ],
    );
  }

  Widget _allergenSection(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final showWithdraw =
        _isEdit && (widget.existing?.hasAllergenConsent ?? false);
    return FormSection(
      title: l10n.familyAllergenSectionTitle,
      badge: l10n.familyOptionalBadge,
      children: [
        Text(
          l10n.familyAllergenHealthNote,
          style: AppTextStyles.captionText.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        FormCheckRow(
          label: l10n.familyAllergenConsentText(
            _consentName(minorContext: false),
          ),
          value: _allergenConsent,
          onChanged: (v) => setState(() {
            _allergenConsent = v;
            if (!_allergenConsent) _allergens = {};
          }),
          bodyStyle: true,
        ),
        if (_allergenConsent)
          FormCheckGrid(
            items: [
              for (final entry in AllergenPreferenceOptions.allergens.entries)
                (
                  label: entry.value,
                  value: _allergens.contains(entry.key),
                  onChanged: (on) => setState(() {
                    if (on) {
                      _allergens.add(entry.key);
                    } else {
                      _allergens.remove(entry.key);
                    }
                  }),
                ),
            ],
          ),
        // Withdraw sits inside the section so it's clearly the control that
        // erases the allergen data shown above (consent-clarity).
        if (showWithdraw)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ButleryTextButton(
              onPressed: _withdraw,
              label: l10n.familyWithdrawAllergenConsent,
              tone: ButleryTextButtonTone.danger,
            ),
          ),
      ],
    );
  }

  /// Disliked-ingredients picker. A soft preference with no consent friction —
  /// always shown, no checkbox gate (unlike the allergen section).
  Widget _dislikesSection(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return FormSection(
      title: l10n.familyDislikesSectionTitle,
      badge: l10n.familyOptionalBadge,
      children: [
        Text(
          l10n.familyDislikesNote,
          style: AppTextStyles.captionText.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Wrap(
          spacing: AppDimensions.space8,
          runSpacing: AppDimensions.space8,
          children: [
            for (final entry in _dislikeOptions.entries)
              FormChoice(
                label: entry.value,
                selected: _dislikes.contains(entry.key),
                onSelected: (on) => setState(() {
                  if (on) {
                    _dislikes.add(entry.key);
                  } else {
                    _dislikes.remove(entry.key);
                  }
                }),
              ),
          ],
        ),
      ],
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
          color: context.modeColors.heroPaleGreen,
          child: Row(
            children: [
              ButleryIcon(
                ButleryIcons.shieldCheck,
                size: AppDimensions.iconSize18,
                color: cs.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.familyConsentGivenPrefix} $date · ${consent.consentVersion}',
                  style: AppTextStyles.captionText.copyWith(
                    color: cs.onSurface,
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
    padding: const EdgeInsets.only(bottom: AppDimensions.space8),
    child: Text(
      (_vm.error).orEmpty(),
      style: AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}
