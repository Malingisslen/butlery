// lib/widgets/common/navigation/add_sheet.dart
//
// PQ-17: what the shell's plus opens. Skarmar v12 del 1 #plussheet: "Mitten-
// plus öppnar ark: Snabbspara är arkets enda fyllda hjältehandling,
// importvägarna ligger som pappersytor med inkkontur. Handtag i
// border-control, 12 px överkant. Fokus flyttas in i arket, fälls in och
// återgår till plusknappen vid stängning."
//
// The modal route moves focus into the sheet and hands it back to the plus
// when the sheet closes; the sheet's frame (12 px top edge, handle, surface)
// comes from showButlerySheet and the theme (navigation_themes.dart
// bottomSheetTheme).
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/guest/guest_account_sheet.dart';
import 'package:butlery/widgets/guest/guest_builder.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// Opens the add sheet. A choice closes the sheet and opens its view on the
/// navigator below it, so Back returns to where the plus was.
Future<void> showButleryAddSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  // A guest's choice waits on a read before it lands, so a second tap or a
  // dismissal can come first; only the first choice on a live sheet acts.
  var chosen = false;
  bool takeChoice(BuildContext sheetContext) {
    if (chosen || !sheetContext.mounted) return false;
    return chosen = true;
  }

  return showButlerySheet<void>(
    context: context,
    builder: (sheetContext) => ButleryAddSheet(
      onChoose: (route) {
        if (!takeChoice(sheetContext)) return;
        Navigator.of(sheetContext).pop();
        navigator.pushNamed(route);
      },
      onImportLimit: () {
        if (!takeChoice(sheetContext)) return;
        Navigator.of(sheetContext).pop();
        showGuestAccountSheet(
          navigator.context,
          GuestAccountReason.importLimit,
        );
      },
    ),
  );
}

/// The sheet's content: the hero "Snabbspara" and the import routes.
class ButleryAddSheet extends StatelessWidget {
  const ButleryAddSheet({
    required this.onChoose,
    this.onImportLimit,
    super.key,
  });

  /// Called with the chosen view's route.
  final ValueChanged<String> onChoose;

  /// Called instead of [onChoose] when a guest with no imports left picks
  /// link or photo import.
  final VoidCallback? onImportLimit;

  static const Key quickSaveKey = ValueKey<String>('test-add-sheet-quick-save');

  /// A guest's import starts here: a fresh id for the server to count, and
  /// the limit sheet instead of the view once the three imports are used.
  Future<void> _chooseImport(String route, bool isGuest) async {
    final session = isGuest
        ? ServiceLocator.tryGet<GuestImportSession>()
        : null;
    if (session == null) return onChoose(route);
    session.begin();
    await session.load();
    if (session.remaining == 0 && onImportLimit != null) {
      onImportLimit!();
    } else {
      onChoose(route);
    }
  }

  @override
  Widget build(BuildContext context) => GuestBuilder(
    builder: (context, isGuest) => _build(context, isGuest),
  );

  Widget _build(BuildContext context, bool isGuest) {
    final l10n = context.l10n;
    final countsAsImport = isGuest ? l10n.guestCountsAsImport : null;
    const gap = SizedBox(width: AppDimensions.space8);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMargin,
        0,
        AppDimensions.layoutMargin,
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGuest) const _GuestQuotaLine(),
          Semantics(
            header: true,
            child: Text(l10n.addRecipeTitle, style: AppTextStyles.subpageTitle),
          ),
          const SizedBox(height: AppDimensions.space8),
          // The sheet's one filled hero (#plussheet), with a two-line face.
          Semantics(
            identifier: 'btn-quick-save',
            child: FormButton(
              key: quickSaveKey,
              label: l10n.addSheetQuickSaveTitle,
              onPressed: () => onChoose(Routes.quickCapture),
              content: Row(
                children: [
                  const ButleryIcon(ButleryIcons.zap),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addSheetQuickSaveTitle,
                          style: AppTextStyles.labelLarge,
                        ),
                        Text(
                          l10n.addSheetQuickSaveSubtitle,
                          style: AppTextStyles.captionBase,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-import-url',
                label: l10n.recipeImportLink,
                icon: ButleryIcons.link,
                subtitle: countsAsImport,
                onTap: () => _chooseImport(Routes.smartImport, isGuest),
              ),
              gap,
              _RouteTile(
                identifier: 'btn-write-manually',
                label: l10n.recipeWriteManually,
                icon: ButleryIcons.pencil,
                onTap: () => onChoose(Routes.manualEntry),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-photo-import',
                label: l10n.recipeFromImage,
                icon: ButleryIcons.image,
                subtitle: countsAsImport,
                onTap: () => _chooseImport(Routes.photoImport, isGuest),
              ),
              gap,
              _RouteTile(
                identifier: 'btn-archive-import',
                label: l10n.recipeFromArchive,
                icon: ButleryIcons.archive,
                onTap: () => onChoose(Routes.importFromArchive),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          // Not drawn in #plussheet. Voice import was reachable from the old
          // "lägg till" tab, so it stays one tap away here, as a paper tile
          // like the other import routes.
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-voice-import',
                label: l10n.recipeVoiceImport,
                icon: ButleryIcons.mic,
                onTap: () => onChoose(Routes.voiceImport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A paper tile with an ink outline (#plussheet): surface.base with a 1.5 px
/// text.primary edge and text.primary content, which is ink in light mode and
/// paper in dark mode (tokens.json semantic text.primary).
class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;

  static const double _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      side: BorderSide(color: cs.onSurface, width: _edge),
    );
    return Expanded(
      child: Semantics(
        identifier: identifier,
        button: true,
        child: Material(
          key: ValueKey('test-add-sheet-$identifier'),
          color: cs.surface,
          shape: shape,
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              customBorder: shape,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space8,
                    vertical: AppDimensions.space16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ButleryIcon(icon, color: cs.onSurface),
                      const SizedBox(height: AppDimensions.space4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.captionBase.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "N av 3 importer kvar som gäst", from the local count; the server decides.
class _GuestQuotaLine extends StatefulWidget {
  const _GuestQuotaLine();

  @override
  State<_GuestQuotaLine> createState() => _GuestQuotaLineState();
}

class _GuestQuotaLineState extends State<_GuestQuotaLine> {
  GuestImportSession? _session;

  @override
  void initState() {
    super.initState();
    _session = ServiceLocator.tryGet<GuestImportSession>()?..load();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.space8),
        child: Text(
          context.l10n.guestImportsLeft(session.remaining),
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
