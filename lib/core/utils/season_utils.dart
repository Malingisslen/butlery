class SeasonUtils {
  SeasonUtils._();

  static String currentSeasonTag([DateTime? now]) {
    final month = (now ?? DateTime.now()).month;
    if (month >= 3 && month <= 5) return 'vår';
    if (month >= 6 && month <= 8) return 'sommar';
    if (month >= 9 && month <= 11) return 'höst';
    return 'vinter';
  }
}
