import 'dart:ui' show Locale;

import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// One push rendered in one language.
class NotificationText {
  final String title;
  final String body;

  const NotificationText({required this.title, required this.body});

  Map<String, String> toMap() => {'title': title, 'body': body};

  static NotificationText? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['title'];
    final body = raw['body'];
    if (title is! String || body is! String) return null;
    return NotificationText(title: title, body: body);
  }
}

/// Variable values that differ by language, keyed by locale code. Overlays the
/// plain `variables` of a send.
typedef LocalizedVariables = Map<String, Map<String, String>>;

/// Builds variables once per supported language, for text the caller writes
/// itself (a rating sentence) rather than takes from the strategy's template.
LocalizedVariables localizedVariables(
  Map<String, String> Function(AppLocalizations l) build,
) => {
  for (final code in LocaleProvider.supportedLocales)
    code: build(lookupAppLocalizations(Locale(code))),
};

String substituteVariables(String template, Map<String, String> variables) {
  var result = template;
  variables.forEach((key, value) {
    result = result.replaceAll('{$key}', value);
  });
  return result;
}

/// The push in every supported language. The recipient's language is not known
/// on the sending device; the server picks the entry that matches it.
Map<String, NotificationText> translateStrategy(
  NotificationStrategy strategy,
  Map<String, String> variables, {
  LocalizedVariables? variablesByLocale,
}) => {
  for (final code in LocaleProvider.supportedLocales)
    code: _translate(
      strategy,
      {...variables, ...?variablesByLocale?[code]},
      code,
    ),
};

NotificationText _translate(
  NotificationStrategy strategy,
  Map<String, String> variables,
  String code,
) {
  final l = lookupAppLocalizations(Locale(code));
  return NotificationText(
    title: substituteVariables(
      strategy.localization['title_$code'] ?? l.notificationDefaultTitle,
      variables,
    ),
    body: substituteVariables(
      strategy.localization['body_$code'] ?? l.notificationDefaultBody,
      variables,
    ),
  );
}
