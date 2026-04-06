/// Dismissible PWA install banner shown after 3 sessions on web.
import 'package:flutter/material.dart';
import 'package:butlery/services/pwa_install_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  late final PwaInstallService _service;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    try {
      _service = ServiceLocator.get<PwaInstallService>();
      _service.initialize().then((_) {
        if (mounted) setState(() => _visible = _service.canPromptInstall);
      });
    } catch (_) {
      _visible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border(top: BorderSide(color: cs.primary, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.install_mobile, color: cs.primary),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              context.l10n.pwaInstallPrompt,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _service.promptInstall();
              setState(() => _visible = false);
            },
            child: Text(context.l10n.pwaInstallAction),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              _service.dismissInstall();
              setState(() => _visible = false);
            },
          ),
        ],
      ),
    );
  }
}
