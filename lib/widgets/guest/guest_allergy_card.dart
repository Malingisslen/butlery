import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_allergy_card_store.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/guest/guest_builder.dart';

/// Hem's "Har någon i hushållet allergier?" card, for a guest who has not yet
/// opened the allergen settings or closed it.
class GuestAllergyCard extends StatelessWidget {
  const GuestAllergyCard({
    this.store = const GuestAllergyCardStore(),
    super.key,
  });

  static const Key actionKey = ValueKey<String>('guest-allergy-action');
  static const Key closeKey = ValueKey<String>('guest-allergy-close');

  final GuestAllergyCardStore store;

  @override
  Widget build(BuildContext context) {
    return GuestBuilder(
      builder: (context, isGuest) {
        if (!isGuest) return const SizedBox.shrink();
        final uid = ServiceLocator.tryGet<AuthService>()?.currentUser?.uid;
        if (uid == null) return const SizedBox.shrink();
        return _Card(uid: uid, store: store);
      },
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({required this.uid, required this.store});

  final String uid;
  final GuestAllergyCardStore store;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.store.isDone(widget.uid).then((done) {
      if (mounted && !done) setState(() => _visible = true);
    });
  }

  void _finish() {
    setState(() => _visible = false);
    widget.store.markDone(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.spacingMd,
          bottom: AppDimensions.spacingMd,
          end: AppDimensions.spacingXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.guestAllergyTitle,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          l10n.guestAllergyBody,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: GuestAllergyCard.closeKey,
                  tooltip: l10n.guestAllergyDismiss,
                  icon: const ButleryIcon(ButleryIcons.x),
                  onPressed: _finish,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingMd - AppDimensions.spacingXs,
              ),
              child: FilledButton(
                key: GuestAllergyCard.actionKey,
                onPressed: () {
                  final navigator = Navigator.of(context);
                  _finish();
                  navigator.pushNamed(Routes.settingsAllergens);
                },
                child: Text(l10n.guestAllergyAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
