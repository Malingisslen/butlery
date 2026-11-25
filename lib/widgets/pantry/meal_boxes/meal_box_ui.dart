/// Shared helpers of the three meal-box surfaces (BUT-2486 part 5): the
/// feature-flag check, analytics events and the box subtitle.
library;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/meal_box.dart';

export 'package:butlery/core/di/meal_box_feature_from_locator.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

IconData mealBoxIcon(MealBoxLocation location) =>
    location == MealBoxLocation.freezer
    ? ButleryIcons.archive
    : ButleryIcons.refrigerator;

String _short(DateFormat format, DateTime date) =>
    format.format(date).replaceAll('.', '');

/// "Kylen · lagat i dag", "Kylen · lagat lör", "Frysen · 9 nov", each with
/// "· 1 tas ons" when lunches take from the box.
String mealBoxSubtitle(
  AppLocalizations l10n,
  String locale,
  MealBox box, {
  DateTime? now,
}) {
  final today = now ?? clock.now();
  final stored = box.storedOn;
  final daysAgo = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(stored.year, stored.month, stored.day)).inDays;
  final monthDay = _short(DateFormat.MMMd(locale), stored);
  final base = switch (box.location) {
    MealBoxLocation.freezer => l10n.mealBoxSubtitleFreezer(monthDay),
    MealBoxLocation.fridge => l10n.mealBoxSubtitleFridge(
      daysAgo <= 0
          ? l10n.mealBoxStoredToday
          : daysAgo < 7
          ? _short(DateFormat.E(locale), stored)
          : monthDay,
    ),
  };
  if (box.takes.isEmpty) return base;
  final tail = box.takes.length == 1
      ? l10n.mealBoxTakenOn(
          box.taken,
          _short(
            DateFormat.E(locale),
            DateTime.tryParse(box.takes.keys.first) ?? stored,
          ),
        )
      : l10n.mealBoxTakenMany(box.taken);
  return '$base · $tail';
}

String mealBoxLocationLabel(AppLocalizations l10n, MealBoxLocation location) =>
    location == MealBoxLocation.freezer
    ? l10n.mealBoxLocationFreezer
    : l10n.mealBoxLocationFridge;
