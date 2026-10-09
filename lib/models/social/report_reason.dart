/// Why a report was filed, as stored on `reports/*.reason`.
///
/// `wireName` is what Firestore keeps and what the `/reports` create rule in
/// `firestore.rules` admits; the visible label comes from l10n and may change
/// without touching stored data. `fromWire` returns null for a value that is
/// not one of these ids, which older reports written as free text are.
library;

enum ReportReason {
  spam('spam'),
  abuse('abuse'),
  harassment('harassment'),
  csam('csam'),
  copyright('copyright'),
  misinformation('misinformation'),
  other('other')
  ;

  const ReportReason(this.wireName);

  final String wireName;

  /// The reasons the report dialog offers, in the order it shows them.
  static const offered = [abuse, spam, harassment, copyright, other];

  static ReportReason? fromWire(String? wire) {
    if (wire == null) return null;
    for (final reason in ReportReason.values) {
      if (reason.wireName == wire) return reason;
    }
    return null;
  }
}
