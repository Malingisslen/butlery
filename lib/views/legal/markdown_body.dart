// lib/views/legal/markdown_body.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Lightweight renderer for the controlled Markdown subset used by our legal
/// documents (privacy policy, terms): `#`/`##`/`###` headings, `---` rules,
/// `-`/`*` bullets, paragraphs, plus inline `**bold**` and `[text](url)` links.
///
/// We render this in-house rather than pull in `flutter_markdown` (discontinued
/// upstream) for one screen. Parsing and link-recognizer creation happen once
/// in [initState]; `build` only assembles styled spans, so there is no
/// per-frame gesture-recognizer leak.
class MarkdownBody extends StatefulWidget {
  final String data;

  const MarkdownBody({super.key, required this.data});

  @override
  State<MarkdownBody> createState() => _MarkdownBodyState();
}

class _MarkdownBodyState extends State<MarkdownBody> {
  late List<_Block> _blocks;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(MarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _disposeRecognizers();
      _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _parse() {
    // Recognizers must be disposed before re-parsing (callers: initState with
    // an empty list, didUpdateWidget after _disposeRecognizers).
    assert(_recognizers.isEmpty,
        '_parse() called without disposing recognizers first');
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
  }

  /// Splits a line into inline tokens, creating (and tracking) a tap recognizer
  /// for every link so it can be disposed with the widget.
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
        final url = m.group(3)!;
        final recognizer = TapGestureRecognizer()..onTap = () => _launch(url);
        _recognizers.add(recognizer);
        tokens.add(_Token.link(m.group(2)!, recognizer));
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
      List<_Token> tokens, TextStyle base, Color linkColor) {
    return [
      for (final t in tokens)
        switch (t.kind) {
          _TokenKind.text => TextSpan(text: t.text, style: base),
          _TokenKind.bold => TextSpan(
              text: t.text,
              style: base.copyWith(fontWeight: FontWeight.bold),
            ),
          _TokenKind.link => TextSpan(
              text: t.text,
              style: base.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ),
              recognizer: t.recognizer,
            ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final linkColor = theme.colorScheme.primary;
    final bodyStyle = tt.bodyMedium?.copyWith(height: 1.6) ?? const TextStyle();

    final children = <Widget>[];
    for (final block in _blocks) {
      switch (block.type) {
        case _BlockType.gap:
          children.add(const SizedBox(height: AppDimensions.spacingS));
        case _BlockType.rule:
          children.add(const Divider(height: AppDimensions.spacingXl));
        case _BlockType.h1:
          children.add(_para(block.tokens, tt.headlineSmall, linkColor,
              top: AppDimensions.spacingM));
        case _BlockType.h2:
          children.add(_para(block.tokens, tt.titleLarge, linkColor,
              top: AppDimensions.spacingM));
        case _BlockType.h3:
          children.add(_para(block.tokens, tt.titleMedium, linkColor,
              top: AppDimensions.spacingS));
        case _BlockType.bullet:
          children.add(Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppDimensions.spacingM,
              bottom: AppDimensions.spacingXs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: bodyStyle),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                        children: _spans(block.tokens, bodyStyle, linkColor)),
                  ),
                ),
              ],
            ),
          ));
        case _BlockType.paragraph:
          children.add(_para(block.tokens, bodyStyle, linkColor,
              top: AppDimensions.spacingXs));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _para(List<_Token> tokens, TextStyle? style, Color linkColor,
      {double top = 0}) {
    final base = style ?? const TextStyle();
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: AppDimensions.spacingXs),
      child: Text.rich(
        TextSpan(children: _spans(tokens, base, linkColor)),
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
  final TapGestureRecognizer? recognizer;
  const _Token(this.kind, this.text, [this.recognizer]);

  factory _Token.text(String t) => _Token(_TokenKind.text, t);
  factory _Token.bold(String t) => _Token(_TokenKind.bold, t);
  factory _Token.link(String t, TapGestureRecognizer r) =>
      _Token(_TokenKind.link, t, r);
}
