import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';

/// GDPR Article 7 - Consent Dialog for First-Time Users
///
/// Dialog shown during registration or when consent renewal is required.
/// Allows users to grant/deny consent for different data processing purposes.
///
/// **Features:**
/// - Clear explanation of each consent purpose
/// - Accept all / Reject optional shortcuts
/// - Individual purpose toggles
/// - GDPR compliant consent tracking
class ConsentDialog extends StatefulWidget {
  final bool isFirstTime; // True for registration, false for renewal
  final VoidCallback? onConsentGranted;
  final VoidCallback? onConsentDenied;

  const ConsentDialog({
    super.key,
    this.isFirstTime = true,
    this.onConsentGranted,
    this.onConsentDenied,
  });

  /// Show consent dialog
  static Future<bool> show(
    BuildContext context, {
    bool isFirstTime = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must make a choice
      builder: (context) => ConsentDialog(isFirstTime: isFirstTime),
    );
    return result ?? false;
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConsentViewModel>(
      builder: (context, viewModel, _) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntroText(),
                        const SizedBox(height: 24),
                        _buildRequiredConsentsSection(),
                        const SizedBox(height: 24),
                        _buildOptionalConsentsSection(viewModel),
                        const SizedBox(height: 24),
                        if (viewModel.hasError) _buildErrorMessage(viewModel),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(context, viewModel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.privacy_tip_rounded,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isFirstTime
                      ? 'Välkommen till Butlery!'
                      : 'Uppdatera dina samtycken',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Integritet och dataskydd',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroText() {
    return Text(
      widget.isFirstTime
          ? 'Innan du börjar använda Butlery behöver vi ditt samtycke för att behandla dina personuppgifter enligt GDPR.'
          : 'Vår integritetspolicy har uppdaterats. Granska och uppdatera dina samtycken.',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[800],
        height: 1.5,
      ),
    );
  }

  Widget _buildRequiredConsentsSection() {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                SizedBox(width: 8),
                Text(
                  'Nödvändiga samtycken',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequiredConsentItem(
              'Grundläggande tjänster',
              'Nödvändigt för att appen ska fungera (autentisering, säkerhet, grundfunktioner).',
            ),
            const SizedBox(height: 8),
            _buildRequiredConsentItem(
              'Databehandling',
              'Lagring och behandling av dina recept, menyer och inköpslistor.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredConsentItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalConsentsSection(ConsentViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Valfria samtycken',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: viewModel.isSaving ? null : viewModel.acceptAll,
                  child: const Text('Acceptera alla'),
                ),
                TextButton(
                  onPressed: viewModel.isSaving ? null : viewModel.rejectAll,
                  child: const Text('Avvisa alla'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Analysdata',
          'Hjälp oss förbättra appen genom att dela användningsstatistik.',
          Icons.analytics_rounded,
          viewModel.analytics,
          viewModel.setAnalytics,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Marknadsföring',
          'Ta emot nyhetsbrev och erbjudanden om nya funktioner.',
          Icons.mail_rounded,
          viewModel.marketing,
          viewModel.setMarketing,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Sociala funktioner',
          'Dela recept med vänner och se andras skapelser.',
          Icons.people_rounded,
          viewModel.socialFeatures,
          viewModel.setSocialFeatures,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Push-notiser',
          'Få meddelanden om kommentarer, delningar och uppdateringar.',
          Icons.notifications_rounded,
          viewModel.pushNotifications,
          viewModel.setPushNotifications,
        ),
      ],
    );
  }

  Widget _buildConsentToggle(
    ConsentViewModel viewModel,
    String title,
    String description,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: value ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: viewModel.isSaving ? null : onChanged,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(ConsentViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              viewModel.errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ConsentViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: viewModel.isSaving ? null : () => _handleSaveConsent(context, viewModel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: viewModel.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Spara samtycken',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Genom att fortsätta godkänner du de nödvändiga samtycken och dina val för valfria samtycken. Du kan ändra dina val när som helst i inställningarna.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveConsent(BuildContext context, ConsentViewModel viewModel) async {
    final success = await viewModel.saveConsent();

    if (success && context.mounted) {
      widget.onConsentGranted?.call();
      Navigator.of(context).pop(true);
    } else if (!success) {
      widget.onConsentDenied?.call();
    }
  }
}
