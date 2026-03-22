import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
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
          const SizedBox(height: AppDimensions.spacingL),
          ElevatedButton.icon(
            onPressed: () => _handleContactUs(context),
            icon: const Icon(Icons.email_rounded),
            label: Text(context.l10n.privacyContactUs),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContactUs(BuildContext context) async {
    final subject = Uri.encodeComponent(context.l10n.privacyEmailSubject);
    final uri = Uri.parse('mailto:privacy@butlery.se?subject=$subject');

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

  void _showError(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onError),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
