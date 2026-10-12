// lib/widgets/legal/legal_link_foot.dart
//
// The foot of a legal document (Skärmar v12 #juridik): the other documents
// and the contact address as saffron links on one line.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/constants/support_mail.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_link.dart';

enum LegalDocumentKind { terms, privacy, guidelines }

class LegalLinkFoot extends StatelessWidget {
  /// [current] is left out of the links; it is the page the foot sits on.
  const LegalLinkFoot({this.current, super.key});

  final LegalDocumentKind? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linkStyle = AppTextStyles.bodyMedium.copyWith(
      color: ModeColors.of(Theme.of(context).brightness).textLink,
      decoration: TextDecoration.underline,
    );

    Widget link(String label, VoidCallback onTap) => ButleryLink(
      semanticLabel: label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space4),
        child: Text(label, style: linkStyle),
      ),
    );

    void open(String route) => Navigator.pushNamed(context, route);

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Wrap(
        children: [
          if (current != LegalDocumentKind.terms)
            link(l10n.legalLinkTerms, () => open(Routes.termsOfService)),
          if (current != LegalDocumentKind.privacy)
            link(l10n.legalLinkPrivacy, () => open(Routes.privacyPolicy)),
          if (current != LegalDocumentKind.guidelines)
            link(
              l10n.legalLinkGuidelines,
              () => open(Routes.communityGuidelines),
            ),
          link(l10n.legalLinkContact, () => _contact(context)),
        ],
      ),
    );
  }

  Future<void> _contact(BuildContext context) async {
    final l10n = context.l10n;
    final subject = Uri.encodeComponent(l10n.privacyEmailSubject);
    final uri = Uri.parse('mailto:$privacyMailAddress?subject=$subject');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } on Exception catch (e) {
      app_logger.AppLogger.error('[LegalLinkFoot] Failed to launch email', e);
    }
    if (context.mounted) {
      SnackBarUtils.showFailure(context, what: l10n.privacyCouldNotOpenEmail);
    }
  }
}
