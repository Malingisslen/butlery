// lib/widgets/common/butlery_top_bar.dart
//
// Toppfältet — ett gemensamt fält på båda plattformarna.
//
// Komponentark v1 §01 (rad 55–99) ritar fyra giltiga mönster och säger
// "Inga andra varianter. Aldrig X och bakåtpil i samma vy." (rad 57). Två av
// dem är Scaffold.appBar-formade och byggs här:
//
//   1 · Rotnivå   — ButleryTopBar.rot:      ingen bakåtpil, titel i Display
//                   kompakt, sekundärrad under, åtgärder med 48 dp hitbox
//                   (Komponentark rad 68; Grafisk manual v6 rad 422).
//   2 · Undersida — ButleryTopBar.undersida: bakåtpil + titel i 14/700,
//                   bakåtpilens namn "Tillbaka till <vy>" (Komponentark
//                   rad 74–78; tillgänglighetshandoff rad 132).
//
// Mönster 3 (mediehero) och 4 (modal/ark) är inte fält ovanför innehållet
// utan delar av bilden respektive arket, och byggs med vyerna i paket 4.
//
// Beslut B-45 (beslutslogg.md rad 52): ingen Cupertino-gren. Plattformskänslan
// sitter i rörelse och gest, inte i fältets form.
//
// Fältet är ljust (beslut D2, paket 2): papper med ink-text, i mörkt läge
// samma tokens mörka värden. Ingen accentlinje och ingen dekorillustration —
// de fyra mönstren är uttömmande, och det är en tolkning av en tystnad.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Vilket av Komponentarkets toppfältsmönster ett [ButleryTopBar] ritar.
enum ButleryTopBarPattern {
  /// Mönster 1 · Rotnivå. Aldrig en bakåtpil.
  rot,

  /// Mönster 2 · Undersida. Bakåtpil när det finns något att gå tillbaka till.
  undersida,
}

/// Det kanoniska toppfältet.
///
/// Bygg det med [ButleryTopBar.rot] eller [ButleryTopBar.undersida]. Det finns
/// ingen fri konstruktor, eftersom arket inte tillåter fler varianter.
///
/// Höjden följer innehållet. [preferredSize] är taket Scaffold får: det som
/// behövs vid 200 % text (tillgänglighetshandoff rad 85), så att ingenting
/// klipps när texten växer. Vid vanlig textstorlek tar fältet bara den plats
/// innehållet kräver.
class ButleryTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Mönster 1 · Rotnivå (Komponentark v1 rad 60–68).
  ///
  /// Ingen bakåtpil, inte ens när rutten går att poppa. [leading] finns för
  /// vytillstånd som byter ut fältets vänstra del (till exempel flervalsläget i
  /// paket 5) och är aldrig en bakåtpil.
  const ButleryTopBar.rot({
    required this.title,
    this.secondaryLine,
    this.secondaryLineIsLive = true,
    this.actions = const [],
    this.leading,
    this.trailing,
    this.bottom,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.systemOverlayStyle,
    this.elevation = 0,
    super.key,
  }) : pattern = ButleryTopBarPattern.rot,
       backTo = null,
       onBack = null;

  /// Mönster 2 · Undersida (Komponentark v1 rad 71–78).
  ///
  /// [backTo] är namnet på vyn bakåtpilen leder till, och ger det
  /// tillgängliga namnet "Tillbaka till [backTo]". Utan det heter pilen
  /// "Tillbaka", precis som i dag — inget fält får ett sämre namn än det hade.
  ///
  /// [leading] ersätter bakåtpilen helt. Ett X i en modal är mönster 4, inte
  /// det här fältet: ett fält med [leading] ritar aldrig en bakåtpil bredvid.
  const ButleryTopBar.undersida({
    required this.title,
    this.backTo,
    this.onBack,
    this.secondaryLine,
    this.secondaryLineIsLive = true,
    this.actions = const [],
    this.leading,
    this.trailing,
    this.bottom,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.systemOverlayStyle,
    this.elevation = 0,
    super.key,
  }) : pattern = ButleryTopBarPattern.undersida;

  /// Vilket mönster fältet ritar.
  final ButleryTopBarPattern pattern;

  /// Vyns titel. Visas som den skrivs — fältet ändrar aldrig skiftläget.
  final String title;

  /// Raden under titeln, till exempel "Veckans inköp · 4 av 16 klara".
  final String? secondaryLine;

  /// Om sekundärraden annonseras när den ändras (liveRegion). Sant som
  /// standard, eftersom raden oftast bär ett antal. Sätt falskt när raden är
  /// fast text.
  final bool secondaryLineIsLive;

  /// Namnet på vyn bakåtpilen leder till. Bara för [ButleryTopBar.undersida].
  final String? backTo;

  /// Vad bakåtpilen gör. Null ger [Navigator.maybePop].
  final VoidCallback? onBack;

  /// Åtgärder till höger. Var och en får minst 48 × 48 dp träffyta och 8 dp
  /// till grannen (tokens.json touchTarget, rad 485–492).
  final List<Widget> actions;

  /// Ersätter fältets vänstra del. Aldrig tillsammans med en bakåtpil.
  final Widget? leading;

  /// Sist till höger, efter [actions] (till exempel avatarbrickan).
  final Widget? trailing;

  /// Något under fältet, till exempel en flikrad.
  final PreferredSizeWidget? bottom;

  /// Centrera titeln. Båda ritade mönstren är vänsterställda.
  final bool centerTitle;

  /// Ersätter fältets yta. Null ger surface.base i aktuellt läge.
  final Color? backgroundColor;

  /// Ersätter text- och ikonfärgen, även sekundärradens. Null ger
  /// text.primary (och text.secondary på sekundärraden) i aktuellt läge.
  final Color? foregroundColor;

  /// Ersätter titelns stil. Färgen kommer från [foregroundColor] om stilen
  /// inte bär en egen.
  final TextStyle? titleStyle;

  /// Statusfältets stil. Null härleds ur ytans ljushet.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Fältets höjd över innehållet. Ritningen har ingen skugga, så 0.
  final double elevation;

  // ── Mått ────────────────────────────────────────────────────────────────

  /// Minsta träffyta (tokens.json touchTarget.min, rad 486).
  static const double hitbox = AppDimensions.minTouchTarget;

  /// Avstånd mellan åtgärder (tokens.json touchTarget.minGap, rad 488).
  static const double actionGap = AppDimensions.spacingSm;

  /// Undersidans lägsta höjd: appens verktygsradshöjd. Ingen kanonisk källa
  /// anger ett tal, så dagens höjd står kvar.
  static const double subpageMinHeight = kToolbarHeight;

  /// Textskalan taket räknas för (tillgänglighetshandoff rad 85: 200 %).
  static const double _ceilingTextScale = 2.0;

  /// Rotnivåns titel får bryta på två rader innan den ellipseras.
  static const int _rootTitleMaxLines = 2;

  /// Sekundärraden får bryta på två rader innan den ellipseras.
  static const int _secondaryMaxLines = 2;

  // Komponentark rad 62/73 ritar 16 px ovan och 14 px under innehållet.
  // Värdena läggs på skalan i tokens.json space.scale (rad 468–475).
  static const double _padTop = AppDimensions.spacingMd;
  static const double _padBottom = AppDimensions.spacingL;
  static const double _padSide = AppDimensions.spacingMd;

  /// Komponentark rad 74: bakåtpilens hitbox sticker ut 10 px åt vänster ur
  /// 18 px kant, så hitboxen börjar 8 px in.
  static const double _subpageLeadingInset = AppDimensions.spacingSm;

  /// Komponentark rad 64: sekundärraden står 2 px under titeln.
  static const double _secondaryGap = AppDimensions.spacingXxs;

  bool get _isRoot => pattern == ButleryTopBarPattern.rot;

  TextStyle get _resolvedTitleStyle =>
      titleStyle ??
      (_isRoot ? AppTextStyles.headlineMedium : AppTextStyles.subpageTitle);

  static TextStyle get _secondaryStyle => AppTextStyles.captionBase.copyWith(
    // Komponentark rad 64: font-variant-numeric: tabular-nums.
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// En rads höjd vid taket. Avrundas uppåt, eftersom textmotorn lägger
  /// varje rad på hela pixlar.
  static double _lineHeight(TextStyle style) =>
      ((style.fontSize ?? 14) * (style.height ?? 1.0) * _ceilingTextScale)
          .ceilToDouble();

  @override
  Size get preferredSize {
    final titleLines = _isRoot ? _rootTitleMaxLines : 1;
    var text = _lineHeight(_resolvedTitleStyle) * titleLines;
    if (secondaryLine != null) {
      text += _secondaryGap + _lineHeight(_secondaryStyle) * _secondaryMaxLines;
    }
    final content = text > hitbox ? text : hitbox;
    var height = _padTop + content + _padBottom;
    if (!_isRoot && height < subpageMinHeight) height = subpageMinHeight;
    return Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    // Färgerna kommer ur temats ColorScheme, som byts med läget. Varje slot
    // är en token (lib/theme/app_colors.dart, lightColorScheme och
    // darkColorScheme):
    //   surface          = surface.base   #F5F4ED ljust / #17251D mörkt
    //                      (tokens.json rad 104–107)
    //   onSurface        = text.primary   #24382C ljust / #F5F4ED mörkt
    //                      (tokens.json rad 54)
    //   onSurfaceVariant = text.secondary #627061 ljust / #93A48D mörkt
    //                      (tokens.json rad 62)
    final cs = Theme.of(context).colorScheme;
    final background = backgroundColor ?? cs.surface;
    final foreground = foregroundColor ?? cs.onSurface;
    // text.secondary är mätt mot surface.base. På en annan yta vet fältet
    // inget om kontrasten, så sekundärraden följer då förgrundsfärgen.
    final secondary = foregroundColor ?? cs.onSurfaceVariant;

    final overlay =
        systemOverlayStyle ??
        (ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);

    final leadingWidget = leading ?? _backButton(context);

    final titleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // Sidtiteln är vyns rubrik på nivå 1 (tillgänglighetshandoff
        // rad 135), och den syns som den skrivs.
        Semantics(
          header: true,
          headingLevel: 1,
          child: Text(
            title,
            key: const ValueKey('butleryTopBar.title'),
            style: _resolvedTitleStyle.copyWith(
              color: _resolvedTitleStyle.color ?? foreground,
            ),
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            maxLines: _isRoot ? _rootTitleMaxLines : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (secondaryLine != null) ...[
          const SizedBox(height: _secondaryGap),
          Semantics(
            liveRegion: secondaryLineIsLive,
            child: Text(
              secondaryLine!,
              key: const ValueKey('butleryTopBar.secondaryLine'),
              style: _secondaryStyle.copyWith(color: secondary),
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              maxLines: _secondaryMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    final trailingWidgets = <Widget>[
      for (final action in actions) _Hitbox(child: action),
      if (trailing != null) _Hitbox(child: trailing!),
    ];

    final row = Row(
      crossAxisAlignment: _isRoot
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (leadingWidget != null) ...[
          _Hitbox(child: leadingWidget),
          const SizedBox(width: actionGap),
        ],
        Expanded(child: titleColumn),
        if (trailingWidgets.isNotEmpty) ...[
          const SizedBox(width: actionGap),
          Row(
            key: const ValueKey('butleryTopBar.actions'),
            mainAxisSize: MainAxisSize.min,
            spacing: actionGap,
            children: trailingWidgets,
          ),
        ],
      ],
    );

    final toolbar = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        leadingWidget != null ? _subpageLeadingInset : _padSide,
        _isRoot ? _padTop : AppDimensions.spacingXs,
        _padSide,
        _isRoot ? _padBottom : AppDimensions.spacingXs,
      ),
      child: row,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Material(
        color: background,
        elevation: elevation,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(foregroundColor: foreground),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _isRoot ? 0 : subpageMinHeight,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        heightFactor: 1,
                        child: toolbar,
                      ),
                    ),
                    ?bottom,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bakåtpilen, eller null när fältet inte ska ha någon.
  ///
  /// Rotnivån har aldrig en (Komponentark rad 68). Undersidan har en när
  /// [onBack] är satt eller rutten går att poppa.
  Widget? _backButton(BuildContext context) {
    if (_isRoot) return null;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    if (onBack == null && !canPop) return null;
    final name = backTo == null
        ? context.l10n.commonBack
        : context.l10n.commonBackTo(backTo!);
    return IconButton(
      key: const ValueKey('butleryTopBar.back'),
      // Komponentark rad 74 ritar en chevron (M15 6l-6 6 6 6), samma på
      // båda plattformarna (B-45).
      icon: const Icon(Icons.chevron_left),
      tooltip: name,
      onPressed: onBack ?? () => Navigator.maybePop(context),
    );
  }
}

/// Minst 48 × 48 dp träffyta runt en åtgärd (tokens.json touchTarget).
///
/// Hitboxen finns i koden, inte bara i ritningen. En åtgärd som redan är
/// större behåller sin storlek.
class _Hitbox extends StatelessWidget {
  const _Hitbox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: ButleryTopBar.hitbox,
        minHeight: ButleryTopBar.hitbox,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
