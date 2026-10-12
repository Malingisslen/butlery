// lib/widgets/legal/legal_document.dart
//
// A legal document as the sketch draws it (Skärmar v12 #juridik): the
// markdown on paper under the date and version line, and the contact footer
// pinned below. The privacy policy, the terms and the community guidelines
// share it, so they cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/widgets/legal/legal_contact_footer.dart';

class LegalDocument extends StatelessWidget {
  const LegalDocument({
    required this.content,
    this.webLinksEnabled = true,
    super.key,
  });

  final String content;
  final bool webLinksEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.layoutMarginOf(context),
              vertical: AppDimensions.space16,
            ),
            // Offline, web links cannot open, so they turn inactive and
            // say why (Grafisk manual v6:665 'åtgärder som kräver nät blir
            // inaktiva med förklarande text').
            child: SelectionArea(
              child: MarkdownBody(
                data: content,
                webLinksEnabled: webLinksEnabled,
              ),
            ),
          ),
        ),
        const LegalContactFooter(),
      ],
    );
  }
}
