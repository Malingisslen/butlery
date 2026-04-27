/// Acquisition attribution repository interface.
///
/// Tracks the first UTM-tagged deep link click per user (BUT-612). Enables
/// retention/cohort slicing by acquisition channel server-side, complementing
/// the Firebase Analytics user properties set on the client.
library;

import 'package:butlery/models/acquisition_attribution.dart';

abstract class AcquisitionRepository {
  /// Read the user's stored acquisition attribution, or null if none.
  /// Used to dedupe before writing — first-write-wins.
  Future<AcquisitionAttribution?> getAcquisition(String userId);

  /// Write acquisition attribution for the user. Implementations MUST guard
  /// against overwriting an existing record (first-write-wins).
  ///
  /// Returns true if the write happened, false if a record already existed.
  Future<bool> setAcquisitionIfAbsent(
    String userId,
    AcquisitionAttribution attribution,
  );
}
