// lib/widgets/common/profile/handlers/gdpr_consent_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/views/account/data_export_view.dart';
import 'package:butlery/views/account/consent_management_view.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';

/// Handler for GDPR-related actions.
/// Provides navigation to privacy policy, consent management, and data export.
class GdprConsentHandler {
  /// Handle privacy policy view - GDPR Article 13/14.
  static Future<void> handlePrivacyPolicy(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Navigate to privacy policy view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrivacyPolicyView(),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open privacy policy', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna integritetspolicy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle consent management - GDPR Article 7.
  static Future<void> handleManageConsent(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Get consent service
      final consentService = ServiceLocator.get<ConsentService>();

      // Create view model with the service
      final viewModel = ConsentViewModel(consentService: consentService);

      // Navigate to consent management view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const ConsentManagementView(),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open consent management', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna samtyckeshantering: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle data export - GDPR Article 20.
  static Future<void> handleExportData(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Get data export service
      final exportService = ServiceLocator.get<DataExportService>();

      // Create view model with the service
      final viewModel = DataExportViewModel(exportService: exportService);

      // Navigate to data export view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const DataExportView(),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open data export', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna dataexport: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
