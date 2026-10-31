import 'package:flutter/foundation.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// Why the photo import is offering to let AI read the photo.
enum PhotoAiOfferReason {
  /// The phone could not read a page.
  phoneCouldNotRead,

  /// The phone read the text but no recipe was found in it.
  noRecipeFound,

  /// Handwriting, which only the AI reading handles.
  handwriting,
}

/// The offer to send a photo to the AI reading (consent variant B, Malin
/// 2026-10-31): the phone reads first, and a photo leaves the device only
/// after the person says yes in the offer. Saying yes is the AI-processing
/// consent, recorded through [ConsentService] before anything is sent.
mixin PhotoImportAiOfferMixin on ImportBaseViewModel {
  PhotoAiOfferReason? _aiOffer;
  bool _aiConsentGiven = false;

  /// Test seams for the consent store.
  @visibleForTesting
  Future<bool> Function()? hasAiConsentOverride;
  @visibleForTesting
  Future<bool> Function()? grantAiConsentOverride;

  /// The offer the view shows, or null when there is none.
  PhotoAiOfferReason? get aiOffer => _aiOffer;

  /// Whether the person had already consented when the offer was made. The
  /// view then leaves out the consent sentence, but still asks before sending.
  bool get aiConsentAlreadyGiven => _aiConsentGiven;

  @protected
  Future<bool> hasAiConsent() async {
    final override = hasAiConsentOverride;
    if (override != null) return override();
    final service = ServiceLocator.tryGet<ConsentService>();
    if (service == null) return false;
    return service.hasConsent(ConsentPurpose.aiProcessing);
  }

  @protected
  Future<void> offerAi(PhotoAiOfferReason reason) async {
    _aiConsentGiven = await hasAiConsent();
    if (isDisposed) return;
    _aiOffer = reason;
    notifyListeners();
  }

  /// Takes the pending offer away and returns its reason.
  @protected
  PhotoAiOfferReason? takeAiOffer() {
    final reason = _aiOffer;
    _aiOffer = null;
    notifyListeners();
    return reason;
  }

  @protected
  void clearAiOffer() {
    if (_aiOffer == null) return;
    _aiOffer = null;
    notifyListeners();
  }

  /// Records the AI-processing consent unless it is already given. On failure
  /// the error is shown and nothing may be sent.
  @protected
  Future<bool> ensureAiConsent() async {
    if (await hasAiConsent()) return true;
    final granted = await _grantAiConsent();
    if (!granted) setError(AppLocale.current.photoAiConsentSaveFailed);
    return granted;
  }

  Future<bool> _grantAiConsent() async {
    final override = grantAiConsentOverride;
    if (override != null) return override();
    final service = ServiceLocator.tryGet<ConsentService>();
    if (service == null) return false;
    final existing = await service.getUserConsent();
    final purposes = (existing?.purposes ?? ConsentPurposes.defaults())
        .copyWith(aiProcessing: true);
    return service.saveConsent(purposes);
  }
}
