import 'package:butlery/core/constants/support_mail.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contact footer used at the bottom of legal views (privacy policy, terms, community guidelines).
/// Opens the user's email client with a pre-filled subject line.
class LegalContactFooter extends StatelessWidget {
  const LegalContactFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.privacyQuestionsTitle,
            style: AppTextStyles.bodyBold,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space12),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.privacyContactUs,
            icon: ButleryIcons.mail,
            onPressed: () => _handleContactUs(context),
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Future<void> _handleContactUs(BuildContext context) async {
    final subject = Uri.encodeComponent(context.l10n.privacyEmailSubject);
    final uri = Uri.parse('mailto:$privacyMailAddress?subject=$subject');

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          _showError(context, context.l10n.privacyCouldNotOpenEmail);
        }
      }
    } on Exception catch (e) {
      app_logger.AppLogger.error(
        '[LegalContactFooter] Failed to launch email',
        e,
      );
      if (context.mounted) {
        _showError(context, context.l10n.privacyCouldNotOpenEmail);
      }
    }
  }

  /// The ink snackbar (Komponentark v1:745-750; PQ-09 = A), never a red
  /// status fill (Komponentark v1:300); the message says what failed.
  void _showError(BuildContext context, String message) {
    SnackBarUtils.showFailure(context, what: message);
  }
}
