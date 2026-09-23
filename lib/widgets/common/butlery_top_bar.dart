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
// Rotnivån är ljus: papper med ink-text, i mörkt läge samma tokens mörka
// värden (Komponentark v1 rad 62). Undersidan är mörk: surface.ink med
// papperstext, samma i båda lägena (Komponentark v1 rad 73). Ingen accentlinje och ingen dekorillustration —
// de fyra mönstren är uttömmande, och det är en tolkning av en tystnad.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

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
       onBack = null,
       implyBack = false;

  /// Mönster 2 · Undersida (Komponentark v1 rad 71–78).
  ///
  /// [backTo] är namnet på vyn bakåtpilen leder till, och ger det
  /// tillgängliga namnet "Tillbaka till [backTo]". Utan det heter pilen
  /// "Tillbaka", precis som i dag — inget fält får ett sämre namn än det hade.
  ///
  /// [leading] ersätter bakåtpilen helt. Ett X i en modal är mönster 4, inte
  /// det här fältet: ett fält med [leading] ritar aldrig en bakåtpil bredvid.
  ///
  /// Tolkning av en tystnad: arket ritar undersidan med bara bakåtpil och
  /// titel (rad 73–78). [secondaryLine], [actions] och [trailing] finns ändå
  /// här, eftersom dagens undersidor bär dem, och ritas som på rotnivån.
  const ButleryTopBar.undersida({
    required this.title,
    this.backTo,
    this.onBack,
    this.implyBack = true,
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

  /// Om undersidan ritar bakåtpilen när rutten går att poppa. Falskt ger en
  /// undersida utan pil, för en vy som själv säger att den inte har någon
  /// väg tillbaka (BaseScaffold.showBackButton). [onBack] ger alltid en pil.
  final bool implyBack;

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

  /// Ersätter fältets yta. Null ger surface.base på rotnivån och surface.ink
  /// på undersidan.
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

  /// Undersidans lägsta höjd, 56 dp. Komponentark rad 73–74 ritar 58 px:
  /// 16 px ovan och 14 px under, men bakåtpilens 48 px hitbox sticker ut
  /// 10 px åt båda hållen, så det står 6 px ovan och 4 px under hitboxen.
  /// På skalan (tokens.json space.scale, rad 468–475) blir det 4 + 48 + 4 =
  /// 56. Tolkning: 6 px läggs på 4, inte på 8.
  static const double subpageMinHeight =
      _subpagePadVertical + hitbox + _subpagePadVertical;

  /// Textskalan taket räknas för (tillgänglighetshandoff rad 85: 200 %).
  static const double _ceilingTextScale = 2.0;

  /// Rotnivåns titel får bryta på två rader innan den ellipseras.
  static const int _rootTitleMaxLines = 2;

  /// Sekundärraden får bryta på två rader innan den ellipseras.
  static const int _secondaryMaxLines = 2;

  // Komponentark rad 62 ritar rotnivån med 16 px ovan, 18 px i sidled och
  // 14 px under innehållet. Ovan och under läggs på skalan i tokens.json
  // space.scale (rad 468–475): 16 ovan, 12 under.
  //
  // Sidmarginalen följer tokens.json space.layoutMargin (rad 464–467: 20 vid
  // 320 dp, 24 vid 360–430 dp), så att titeln och innehållet under delar
  // vänsterkant (paket 4, Q-P4-14). Ritningens 18 px är varken 16 eller
  // layoutMargin, och tokenet är innehållets kanoniska rytm. Tolkning.
  static const double _padTop = AppDimensions.spacingMd;
  static const double _padBottom = AppDimensions.spacingL;

  /// Bredden där sidmarginalen går från 20 till 24 (tokens.json
  /// space.layoutMargin: "320" och "360-430").
  static const double _wideFrom = 360;

  /// Sidmarginalen för [context]: tokens.json space.layoutMargin.
  static double sideMargin(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _wideFrom
      ? AppDimensions.layoutMarginNarrow
      : AppDimensions.layoutMargin;

  /// Undersidans luft ovan och under bakåtpilens hitbox. Se
  /// [subpageMinHeight] för hur 6/4 px ur ritningen blir 4/4.
  static const double _subpagePadVertical = AppDimensions.spacingXs;

  /// Komponentark rad 74: bakåtpilens hitbox sticker ut 10 px åt vänster ur
  /// 18 px kant, så hitboxen börjar 8 px in. Samma inset gäller varje
  /// [leading] med 48 dp hitbox, även på rotnivån (tolkning: arket ritar
  /// ingen leading på rotnivån, men en hitbox ska stå lika långt in var den
  /// än står).
  static const double _subpageLeadingInset = AppDimensions.spacingSm;

  /// Komponentark rad 73 ritar 10 px mellan bakåtpilens hitbox och titeln.
  /// Tolkning: 10 läggs på 8, samma som minsta avståndet mellan träffytor
  /// (tokens.json touchTarget.minGap, rad 488), inte på 12.
  static const double _leadingGap = actionGap;

  /// Komponentark rad 64: sekundärraden står 2 px under titeln.
  static const double _secondaryGap = AppDimensions.spacingXxs;

  bool get _isRoot => pattern == ButleryTopBarPattern.rot;

  /// Titelns stil. En [titleStyle] läggs ovanpå mönstrets roll, så att det
  /// som inte anges (till exempel radhöjden) kommer från rollen. Då räknar
  /// [preferredSize] alltid med en känd radhöjd.
  TextStyle get _resolvedTitleStyle =>
      (_isRoot ? AppTextStyles.headlineMedium : AppTextStyles.subpageTitle)
          .merge(titleStyle);

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
    var height = _isRoot
        ? _padTop + content + _padBottom
        : _subpagePadVertical + content + _subpagePadVertical;
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
    //   primary          = surface.ink    #24382C i båda lägena
    //   onPrimary        = papper         #F5F4ED i båda lägena
    // Rotnivån ritas på surface och undersidan på primary (Komponentark v1
    // rad 62 och 73).
    final cs = Theme.of(context).colorScheme;
    final background = backgroundColor ?? (_isRoot ? cs.surface : cs.primary);
    final foreground =
        foregroundColor ?? (_isRoot ? cs.onSurface : cs.onPrimary);
    // text.secondary är mätt mot surface.base. På en annan yta vet fältet
    // inget om kontrasten, så sekundärraden följer då förgrundsfärgen.
    final secondary =
        foregroundColor ?? (_isRoot ? cs.onSurfaceVariant : foreground);

    // An action that needs a selection is off at zero with its name still
    // readable (produktregler.md:876), in the disabled role and never
    // through opacity (tokens.json:71-74). IconButton.styleFrom would
    // otherwise fade the foreground to 38 %. text.disabled.onRaised
    // (#788477 light, #93A48D dark; tokens.json:198) is the surface-safe
    // disabled text and clears 3:1 on surface.base in both modes. On a
    // bar with another surface (the subpage's ink, or a caller's colour)
    // disabled is not drawn, so the fade stays there (beslut-paket2.md,
    // "disabled on surface.ink").
    final Color? disabledForeground = _isRoot && backgroundColor == null
        ? AppModeColors.textDisabled(cs.brightness)
        : null;

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
          const SizedBox(width: _leadingGap),
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

    final padSide = sideMargin(context);
    final toolbar = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        leadingWidget != null ? _subpageLeadingInset : padSide,
        _isRoot ? _padTop : _subpagePadVertical,
        padSide,
        _isRoot ? _padBottom : _subpagePadVertical,
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
          // Fokusringen följer fältets yta, inte temats läge: på undersidans
          // ink är ringen papper även i ljust läge (tokens.json:155-160).
          child: FocusRingSurface(
            brightness: ThemeData.estimateBrightnessForColor(background),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              // Bara förgrundsfärgen byts. Resten av appens ikonknappstema —
              // fokusmarkeringen, 48 dp minsta storlek och ikonstorleken —
              // ärvs, så att fokus syns i fältet precis som utanför det.
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: foreground,
                    disabledForegroundColor: disabledForeground,
                  ).merge(IconButtonTheme.of(context).style),
                ),
                child: TextButtonTheme(
                  data: TextButtonThemeData(
                    style: _onBarTextButtonStyle(context, foreground),
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
        ),
      ),
    );
  }

  /// Appens textknappsstil med fältets förgrund som textfärg.
  ///
  /// Appens textknapp är ink (cs.primary, button_themes.dart). På
  /// undersidans ink-yta (Komponentark v1 rad 73) blev en textknapp bland
  /// åtgärderna ink på ink. Här tar den fältets förgrund, papper på
  /// undersidan och text.primary på rotnivån, precis som ikonknapparna.
  ///
  /// Bara det aktiva läget byts. Det inaktiva behåller appens färg
  /// (text.disabled), eftersom inaktivt på surface.ink inte är ritat (öppen
  /// fråga i beslut-paket2.md, "disabled on surface.ink"). Fokusringen,
  /// 48 dp minsta höjd och resten av stilen ärvs.
  static ButtonStyle _onBarTextButtonStyle(
    BuildContext context,
    Color foreground,
  ) {
    final base = TextButtonTheme.of(context).style;
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return base?.foregroundColor?.resolve(states);
        }
        return foreground;
      }),
    ).merge(base);
  }

  /// Bakåtpilen, eller null när fältet inte ska ha någon.
  ///
  /// Rotnivån har aldrig en (Komponentark rad 68). Undersidan har en när
  /// [onBack] är satt eller rutten går att poppa.
  Widget? _backButton(BuildContext context) {
    if (_isRoot) return null;
    final canPop =
        implyBack && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    if (onBack == null && !canPop) return null;
    final name = backTo == null
        ? context.l10n.commonBack
        : context.l10n.commonBackTo(backTo!);
    return IconButton(
      key: const ValueKey('butleryTopBar.back'),
      // Ikonen är arrow-left, betydelse "Tillbaka" (icons.json rad 76–78).
      // Dess glyf är en vinkel, samma som Komponentark rad 74 ritar, och
      // den är densamma på båda plattformarna (B-45). Material chevron_left
      // står i dess ställe tills Butlerys ikonfamilj når appen.
      //
      // Tolkning: ritningen visar glyfen i 17 px. Här gäller appens
      // ikonknappstema (AppDimensions.iconSizeL), som alla ikonknappar
      // har; arket anger ingen egen storlek för toppfältet.
      icon: const Icon(Icons.chevron_left),
      tooltip: name,
      onPressed: onBack ?? () => Navigator.maybePop(context),
    );
  }
}

/// "Välj" — flervalets synliga ingång (B-46, beslutslogg.md:53;
/// produktregler.md:870-874; Skarmar v12 etapp 9 #flervalingang).
///
/// Samma ord på samma plats på de sex ytorna: i vyns eget toppfält, eller i
/// sektionens rubrikrad där listan ligger i en inställningsvy. En yta med
/// färre än två rader visar det inte alls ([shownFor]).
///
/// Ritningen: 14,5/600 i text.primary, 48 dp hög, 12 px sidluft. Tolkning:
/// appens knappstil (14/600, tokens.json controls.button) gäller, eftersom
/// 14,5 inte finns på typskalan.
class ButlerySelectButton extends StatelessWidget {
  const ButlerySelectButton({
    required this.onPressed,
    this.semanticLabel,
    this.foregroundColor,
    super.key,
  });

  /// Färre rader än så ger ingen ingång: "ett flerval av ett är ingen
  /// funktion" (produktregler.md:874).
  static const int minRows = 2;

  /// Om ingången visas för en lista med [rowCount] valbara rader.
  static bool shownFor(int rowCount) => rowCount >= minRows;

  final VoidCallback onPressed;

  /// Det tillgängliga namnet, till exempel "Välj recept" (ritningens
  /// data-a11y-name). Utan det heter knappen det den visar.
  final String? semanticLabel;

  /// Textfärgen utanför toppfältet. I fältet ger fältet färgen.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('butlery-select-enter'),
      style: _selectionTextStyle(foregroundColor),
      onPressed: onPressed,
      child: Text(context.l10n.selectionEnter, semanticsLabel: semanticLabel),
    );
  }
}

/// "Avbryt" — lämnar flervalet. I toppfältet ersätter den bakåtpilen och
/// står där "Välj" stod i en sektions rubrikrad, så att fältet byter
/// innehåll men inte höjd (produktregler.md:873).
class ButleryCancelSelectionButton extends StatelessWidget {
  const ButleryCancelSelectionButton({
    required this.onPressed,
    this.foregroundColor,
    super.key,
  });

  final VoidCallback onPressed;

  /// Textfärgen utanför toppfältet. I fältet ger fältet färgen.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('butlery-select-cancel'),
      style: _selectionTextStyle(foregroundColor),
      onPressed: onPressed,
      child: Text(context.l10n.commonCancel),
    );
  }
}

ButtonStyle _selectionTextStyle(Color? foregroundColor) => TextButton.styleFrom(
  foregroundColor: foregroundColor,
  // Ritningen: 12 px sidluft (Skarmar v12 etapp 9 #flervalingang).
  padding: const EdgeInsets.symmetric(
    horizontal: AppDimensions.spacingSm + AppDimensions.spacingXs,
  ),
);

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
