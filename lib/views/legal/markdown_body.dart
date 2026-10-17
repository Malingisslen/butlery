// lib/views/legal/markdown_body.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/layout/inline_widget_span.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

/// Lightweight renderer for the controlled Markdown subset used by our legal
/// documents (privacy policy, terms): `#`/`##`/`###` headings, `---` rules,
/// `-`/`*` bullets, paragraphs, plus inline `**bold**` and `[text](url)` links.
///
/// We render this in-house rather than pull in `flutter_markdown` (discontinued
/// upstream) for one screen.
///
/// Drawn as the sketch reads (Skärmar v12 #juridik): the top `#` title is the
/// page bar's job and is not repeated, the lines up to the first `---` are
/// the document's date and version in secondary text,
/// and the headings are bold ink.
class MarkdownBody extends StatefulWidget {
  final String data;

  /// False while the device is offline. Web links (http/https) then render
  /// as plain text without the link role, and one line above the document
  /// says why (Grafisk manual v6:665: actions that need the network become
  /// inactive with an explanatory text, not only dimmed). Mail links stay
  /// active: opening the mail app needs no connection.
  final bool webLinksEnabled;

  /// Drawn right under the date and version line, before the first heading.
  final Widget? afterIntro;

  /// One key per `##` heading in document order, so a table of contents can
  /// scroll to it. Extra keys are ignored.
  final List<GlobalKey> headingKeys;

  const MarkdownBody({
    super.key,
    required this.data,
    this.webLinksEnabled = true,
    this.afterIntro,
    this.headingKeys = const [],
  });

  /// The `##` headings of [data] as the page shows them.
  static List<String> headingsOf(String data) => [
    for (final line in data.split('\n'))
      if (line.startsWith('## ')) displayHeading(line.substring(3).trim()),
  ];

  /// "3. Spam" reads "3 · Spam", as the sketch numbers its sections.
  static String displayHeading(String heading) => heading.replaceFirstMapped(
    RegExp(r'^(\d+)\.\s+'),
    (m) => '${m[1]} · ',
  );

  @override
  State<MarkdownBody> createState() => _MarkdownBodyState();
}

class _MarkdownBodyState extends State<MarkdownBody> {
  late List<_Block> _blocks;
  bool _hasWebLinks = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(MarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _parse();
    }
  }

  void _parse() {
    final blocks = <_Block>[];
    for (final raw in widget.data.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        blocks.add(const _Block(_BlockType.gap, []));
      } else if (trimmed == '---') {
        blocks.add(const _Block(_BlockType.rule, []));
      } else if (line.startsWith('### ')) {
        blocks.add(_Block(_BlockType.h3, _tokenize(line.substring(4))));
      } else if (line.startsWith('## ')) {
        blocks.add(_Block(_BlockType.h2, _tokenize(line.substring(3))));
      } else if (line.startsWith('# ')) {
        blocks.add(_Block(_BlockType.h1, _tokenize(line.substring(2))));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        blocks.add(_Block(_BlockType.bullet, _tokenize(line.substring(2))));
      } else {
        blocks.add(_Block(_BlockType.paragraph, _tokenize(line)));
      }
    }
    _blocks = blocks;
    _hasWebLinks = blocks.any(
      (b) => b.tokens.any((t) => t.kind == _TokenKind.link && _isWebUrl(t.url)),
    );
  }

  static bool _isWebUrl(String? url) {
    if (url == null) return false;
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// Splits a line into inline tokens.
  List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)');
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        tokens.add(_Token.text(text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        tokens.add(_Token.bold(m.group(1)!));
      } else {
        tokens.add(_Token.link(m.group(2)!, m.group(3)!));
      }
      last = m.end;
    }
    if (last < text.length) {
      tokens.add(_Token.text(text.substring(last)));
    }
    return tokens;
  }

  Future<void> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        AppLogger.warning('Could not launch legal-doc link: $url');
      }
    } catch (e) {
      AppLogger.warning('Failed to launch legal-doc link $url: $e');
    }
  }

  List<InlineSpan> _spans(
    List<_Token> tokens,
    TextStyle base,
    Color linkColor,
  ) {
    return [
      for (final t in tokens)
        switch (t.kind) {
          _TokenKind.text => TextSpan(text: t.text, style: base),
          _TokenKind.bold => TextSpan(
            text: t.text,
            style: base.copyWith(fontWeight: FontWeight.bold),
          ),
          // Offline: an inactive web link is plain text, so it neither looks
          // nor announces as something to tap (Grafisk manual v6:665).
          _TokenKind.link when !widget.webLinksEnabled && _isWebUrl(t.url) =>
            TextSpan(text: t.text, style: base),
          // BUT-1446: WidgetSpan + Semantics(link:) so screen readers
          // announce the legal-doc link with a role and name. Replaces the
          // inline TapGestureRecognizer (no link role, audit-invisible) and
          // removes the per-link recognizer-disposal bookkeeping.
          _TokenKind.link => inlineWidgetSpan(
            child: ButleryLink(
              semanticLabel: t.text,
              onTap: () => _launch(t.url!),
              child: Text(
                t.text,
                style: base.copyWith(
                  color: linkColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    // text.link: #8A5212 light, #DCA968 dark.
    final linkColor = ModeColors.of(theme.brightness).textLink;
    final cs = theme.colorScheme;
    final bodyStyle = AppTextStyles.bodyMedium.copyWith(
      color: cs.onSurface,
      height: 1.6,
    );
    final metaStyle = AppTextStyles.captionBase.copyWith(
      color: cs.onSurfaceVariant,
    );
    final headingColor = cs.onSurface;
    var beforeFirstRule = _blocks.any((b) => b.type == _BlockType.rule);
    var h2Index = 0;

    final children = <Widget>[];
    if (!widget.webLinksEnabled && _hasWebLinks) {
      // text.secondary (colorScheme.onSurfaceVariant: #5B6959 light, #A9B2A0
      // dark) on surface.base.
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.space8),
          child: Text(
            context.l10n.legalLinksNeedConnection,
            key: const ValueKey('markdownBody.webLinksOffline'),
            style: tt.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    for (final block in _blocks) {
      switch (block.type) {
        case _BlockType.gap:
          children.add(const SizedBox(height: AppDimensions.space4));
        case _BlockType.rule:
          if (beforeFirstRule) {
            beforeFirstRule = false;
            if (widget.afterIntro != null) children.add(widget.afterIntro!);
          } else {
            children.add(const ButleryDivider(spacing: AppDimensions.space32));
          }
        case _BlockType.h1:
          // The page bar already carries the document's name.
          break;
        case _BlockType.h2:
          final key = h2Index < widget.headingKeys.length
              ? widget.headingKeys[h2Index]
              : null;
          h2Index++;
          children.add(
            KeyedSubtree(
              key: key,
              child: _para(
                [
                  for (final t in block.tokens)
                    t.kind == _TokenKind.text
                        ? _Token.text(MarkdownBody.displayHeading(t.text))
                        : t,
                ],
                AppTextStyles.titleLargeBold.copyWith(color: headingColor),
                linkColor,
                top: AppDimensions.space16,
              ),
            ),
          );
        case _BlockType.h3:
          children.add(
            _para(
              block.tokens,
              AppTextStyles.titleBold.copyWith(color: headingColor),
              linkColor,
              top: AppDimensions.space8,
            ),
          );
        case _BlockType.bullet:
          children.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.space8,
                bottom: AppDimensions.space4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: bodyStyle),
                  Expanded(
                    child: WholeWordText.rich(
                      TextSpan(
                        children: _spans(block.tokens, bodyStyle, linkColor),
                      ),
                      style: bodyStyle,
                    ),
                  ),
                ],
              ),
            ),
          );
        case _BlockType.paragraph:
          children.add(
            _para(
              block.tokens,
              beforeFirstRule ? metaStyle : bodyStyle,
              linkColor,
              top: AppDimensions.space4,
            ),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _para(
    List<_Token> tokens,
    TextStyle style,
    Color linkColor, {
    double top = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppDimensions.space4),
      child: WholeWordText.rich(
        TextSpan(children: _spans(tokens, style, linkColor)),
        style: style,
      ),
    );
  }
}

enum _BlockType { h1, h2, h3, paragraph, bullet, rule, gap }

class _Block {
  final _BlockType type;
  final List<_Token> tokens;
  const _Block(this.type, this.tokens);
}

enum _TokenKind { text, bold, link }

class _Token {
  final _TokenKind kind;
  final String text;
  final String? url;
  const _Token(this.kind, this.text, [this.url]);

  factory _Token.text(String t) => _Token(_TokenKind.text, t);
  factory _Token.bold(String t) => _Token(_TokenKind.bold, t);
  factory _Token.link(String t, String url) => _Token(_TokenKind.link, t, url);
}
