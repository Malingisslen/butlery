// lib/widgets/legal/legal_document.dart
//
// The document reader as the sketch draws it: the date
// and version line, a table of contents whose rows scroll to the sections,
// the sections, and a foot of links. The privacy policy, the terms and the
// community guidelines share it, so they cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/legal/legal_link_foot.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';

class LegalDocument extends StatefulWidget {
  const LegalDocument({
    required this.content,
    this.webLinksEnabled = true,
    this.current,
    super.key,
  });

  final String content;
  final bool webLinksEnabled;

  /// Which document this is, so the foot does not link to itself.
  final LegalDocumentKind? current;

  @override
  State<LegalDocument> createState() => _LegalDocumentState();
}

class _LegalDocumentState extends State<LegalDocument> {
  late List<String> _headings;
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _readHeadings();
  }

  @override
  void didUpdateWidget(LegalDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _readHeadings();
  }

  void _readHeadings() {
    _headings = MarkdownBody.headingsOf(widget.content);
    _keys = [for (final _ in _headings) GlobalKey()];
  }

  void _scrollTo(int index) {
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
        vertical: AppDimensions.space16,
      ),
      // Offline, web links cannot open, so they turn inactive and say why
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarkdownBody(
              data: widget.content,
              webLinksEnabled: widget.webLinksEnabled,
              headingKeys: _keys,
              afterIntro: _headings.length < 2
                  ? null
                  : ButleryListSection(
                      rows: [
                        for (var i = 0; i < _headings.length; i++)
                          ButleryListRow(
                            label: _headings[i],
                            onTap: () => _scrollTo(i),
                          ),
                      ],
                    ),
            ),
            const ButleryDivider(spacing: AppDimensions.space32),
            LegalLinkFoot(current: widget.current),
          ],
        ),
      ),
    );
  }
}
