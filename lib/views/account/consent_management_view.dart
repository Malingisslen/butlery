import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// GDPR Article 7 - Consent Management View for user consent preferences
class ConsentManagementView extends StatefulWidget {
  const ConsentManagementView({super.key});

  @override
  State<ConsentManagementView> createState() => _ConsentManagementViewState();
}

class _ConsentManagementViewState extends State<ConsentManagementView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsentViewModel>().loadConsent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hantera samtycken'),
        centerTitle: true,
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 600,
                desktop: 700,
              ),
            ),
            child: Consumer<ConsentViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.isLoading) {
                  return _buildLoadingState();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(viewModel),
                      const SizedBox(height: 24),
                      _buildRequiredConsentsSection(),
                      const SizedBox(height: 24),
                      _buildOptionalConsentsSection(viewModel),
                      const SizedBox(height: 24),
                      if (viewModel.hasError) _buildErrorMessage(viewModel),
                      if (viewModel.hasError) const SizedBox(height: 16),
                      _buildActionButtons(viewModel),
                      const SizedBox(height: 24),
                      _buildInfoSection(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildHeaderSection(ConsentViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.privacy_tip_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Dina samtycken',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
                'Enligt GDPR har du full kontroll över hur vi behandlar dina personuppgifter. Du kan när som helst ändra eller återkalla dina samtycken.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[700], height: 1.5)),
            if (viewModel.hasConsent) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Senast uppdaterad: ${viewModel.getConsentTimestampText()}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.info))),
                  ],
                ),
              ),
            ],
          ],
        ),
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
            Row(
              children: [
                Icon(Icons.lock, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text('Nödvändiga samtycken',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Dessa samtycken krävs för att appen ska fungera och kan inte inaktiveras.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 16),
            _buildRequiredConsentItem(
              'Grundläggande tjänster',
              'Autentisering, säkerhet och grundläggande funktioner.',
              Icons.security,
            ),
            const SizedBox(height: 12),
            _buildRequiredConsentItem(
              'Databehandling',
              'Lagring och behandling av recept, menyer och inköpslistor.',
              Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredConsentItem(
      String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700], height: 1.4)),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
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
            Text('Valfria samtycken',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed:
                  viewModel.isSaving ? null : () => _handleRevokeAll(viewModel),
              icon: const Icon(Icons.block, size: 16),
              label: const Text('Avvisa alla'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Du kan när som helst aktivera eller inaktivera dessa samtycken.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600])),
        const SizedBox(height: 16),
        _buildConsentToggle(
          viewModel,
          'Analysdata',
          'Hjälp oss förbättra appen genom att dela användningsstatistik. Vi samlar in information om hur du använder appen för att identifiera buggar och förbättra användarupplevelsen.',
          Icons.analytics_rounded,
          viewModel.analytics,
          viewModel.setAnalytics,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Marknadsföring',
          'Ta emot nyhetsbrev och erbjudanden om nya funktioner, recept och uppdateringar via e-post.',
          Icons.mail_rounded,
          viewModel.marketing,
          viewModel.setMarketing,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Sociala funktioner',
          'Dela dina recept med vänner, se andras skapelser och delta i communityn.',
          Icons.people_rounded,
          viewModel.socialFeatures,
          viewModel.setSocialFeatures,
        ),
        const SizedBox(height: 12),
        _buildConsentToggle(
          viewModel,
          'Push-notiser',
          'Få meddelanden om kommentarer på dina recept, när vänner delar med dig och andra aktiviteter.',
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
      elevation: value ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.grey[300]!,
          width: value ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: value ? AppColors.primary : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ConsentViewModel viewModel) {
    return ElevatedButton(
      onPressed:
          viewModel.isSaving ? null : () => _handleSaveConsent(viewModel),
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
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Spara ändringar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: AppColors.info.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Bra att veta',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('Dina ändringar träder i kraft omedelbart'),
            _buildInfoItem('Du kan ändra dina samtycken när som helst'),
            _buildInfoItem(
                'Vi sparar en historik av dina samtycken för att följa GDPR'),
            _buildInfoItem(
                'Att återkalla samtycken påverkar inte tidigare behandling'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveConsent(ConsentViewModel viewModel) async {
    final success = await viewModel.saveConsent();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Samtycken har sparats'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRevokeAll(ConsentViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Återkalla alla valfria samtycken?'),
        content: const Text(
          'Detta kommer att inaktivera alla valfria funktioner som analysdata, marknadsföring, sociala funktioner och push-notiser. Du kan aktivera dem igen när som helst.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Återkalla alla'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await viewModel.revokeAllOptional();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Alla valfria samtycken har återkallats'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
