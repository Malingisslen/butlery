// lib/widgets/common/layout/word_fit.dart
//
// Two questions a row asks before it commits to a side-by-side layout under
// large text: does the widest word fit its share, and is the text scaled at
// all. A word that gets less width than it needs is broken between letters
// ("LUNC" / "H"), so a row that cannot fit its words stacks or scrolls
// instead.
library;

import 'package:flutter/widgets.dart';

final _whitespace = RegExp(r'\s+');

/// The width of the widest word in [texts], drawn in [style] at the text
/// scale in force.
double widestWord(
  BuildContext context,
  Iterable<String> texts,
  TextStyle style, {
  TextScaler? scaler,
}) {
  scaler ??= MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  // A Text merges its style over the ambient one, so the measure must too.
  final drawn = DefaultTextStyle.of(context).style.merge(style);
  var widest = 0.0;
  for (final text in texts) {
    for (final word in text.split(_whitespace)) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: drawn),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
  }
  return widest;
}

/// The text scale at which the widest word of [text] fits [available], or
/// null when it already fits at the scale in force. The result can be below
/// 1, when even the unscaled word is too wide.
double? wordFitScale(
  BuildContext context,
  String text,
  TextStyle style,
  double available,
) {
  final widest = widestWord(context, [text], style);
  if (widest <= available || available <= _fitSlack) return null;
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final first = scale * (available - _fitSlack) / widest;
  // Glyphs do not scale exactly linearly, so the word measured at the new
  // scale can still come out wider than it was asked to be.
  final again = widestWord(
    context,
    [text],
    style,
    scaler: TextScaler.linear(first),
  );
  return again <= available ? first : first * (available - _fitSlack) / again;
}

/// Whether the user has scaled the text up. A row of words and actions that
/// shares one line at 1.0 stacks above it.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1;

/// The text engine lays glyphs out on whole pixels, so a word scaled to the
/// exact width can still come out a pixel wider and break.
const double _fitSlack = 1;

/// Text that wraps between words and never inside one.
///
/// When the widest word does not fit the width it is given, the text is
/// scaled until it does.
class WholeWordText extends StatelessWidget {
  const WholeWordText(
    String this.text, {
    required this.style,
    this.maxLines,
    this.width,
    this.textAlign,
    this.semanticsLabel,
    super.key,
  }) : span = null;

  /// Text with spans of its own (a bold label before the sentence). The
  /// widest word is measured in [style], the base the spans are laid over.
  const WholeWordText.rich(
    InlineSpan this.span, {
    required this.style,
    this.maxLines,
    this.width,
    this.textAlign,
    super.key,
  }) : text = null,
       semanticsLabel = null;

  final String? text;
  final InlineSpan? span;
  final TextStyle style;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  /// Null lets the text take as many lines as it needs.
  final int? maxLines;

  /// The width the text will be given, for a parent that cannot host a
  /// [LayoutBuilder] (an `IntrinsicHeight` asks its children for intrinsic
  /// sizes, which a builder cannot give). Null reads it from the layout.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final known = width;
    if (known != null) return _text(context, known);
    return LayoutBuilder(
      builder: (context, constraints) => _text(context, constraints.maxWidth),
    );
  }

  Widget _text(BuildContext context, double available) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final plain = text ?? span!.toPlainText(includePlaceholders: false);
    final fitted = wordFitScale(context, plain, style, available);
    final scaler = fitted == null ? null : TextScaler.linear(fitted);
    if (span != null) {
      return Text.rich(
        span!,
        style: style,
        textAlign: textAlign,
        textScaler: scaler,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Text(
      text!,
      style: style,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
      textScaler: scaler,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
