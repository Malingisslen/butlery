import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/import/import_manager_result.dart';

/// How the raw material came in. Stored on the parse event, and validated
/// against the same list by the `logParseEvent` Cloud Function.
enum ImportChannel { link, text, photo, voice, file }

/// The one parse event an import writes (BUT-2238), built from the
/// [ImportManager]'s final answer so every channel is measured the same way.
class ImportEvent {
  final ImportChannel channel;

  /// The strategy that gave the final answer, as a short id the Cloud
  /// Function validates: one of [strategyIds].
  final String strategy;

  /// `recipe`, `assistance` or `failure`.
  final String outcome;
  final bool fromCache;
  final int parseTimeMs;
  final String? url;
  final String? successfulTier;
  final String? parserVersion;
  final double? finalQuality;
  final bool usedLlm;
  final double? estimatedCostUsd;
  final String? errorCode;
  final List<Map<String, dynamic>>? tierAttempts;
  final bool unknownDomain;

  const ImportEvent({
    required this.channel,
    required this.strategy,
    required this.outcome,
    required this.parseTimeMs,
    this.fromCache = false,
    this.url,
    this.successfulTier,
    this.parserVersion,
    this.finalQuality,
    this.usedLlm = false,
    this.estimatedCostUsd,
    this.errorCode,
    this.tierAttempts,
    this.unknownDomain = false,
  });

  bool get success => outcome == 'recipe';

  factory ImportEvent.fromResult(
    ImportManagerResult result, {
    required ImportChannel channel,
    required String input,
    required Duration elapsed,
  }) {
    final meta = result.metadata ?? const <String, dynamic>{};
    final outcome = result.isSuccess && result.recipe != null
        ? 'recipe'
        : result.needsAssistance
        ? 'assistance'
        : 'failure';
    final quality = meta['overallQuality'];
    final cost = meta['llmCost'];
    final attempts = meta['tierAttempts'];
    final tier = meta['successfulTier'];
    final version = meta['parserVersion'];
    return ImportEvent(
      channel: channel,
      strategy: strategyId(result.strategy),
      outcome: outcome,
      parseTimeMs: elapsed.inMilliseconds,
      fromCache: meta['fromCache'] == true,
      url: channel == ImportChannel.link ? _withScheme(input.trim()) : null,
      successfulTier: tier is String ? tier : null,
      parserVersion: version is String ? version : null,
      finalQuality: quality is num ? quality.toDouble() : null,
      usedLlm: meta['usedLlm'] == true,
      estimatedCostUsd: cost is num ? cost.toDouble() : null,
      errorCode: outcome == 'failure' ? result.errorCode?.name : null,
      tierAttempts: attempts is List
          ? attempts.whereType<Map<String, dynamic>>().toList()
          : null,
      unknownDomain: meta['unknownDomain'] == true,
    );
  }

  /// The ids [strategyId] can return, in the order it tests them.
  static const strategyIds = [
    'youtube',
    'tiktok',
    'instagram',
    'url',
    'photo',
    'voice',
    'text',
    'archive',
    'file',
    'unknown',
  ];

  /// A link typed without a scheme still names a site: the Cloud Function
  /// reads the domain off the url and can only parse one with a scheme.
  static String _withScheme(String url) =>
      Uri.tryParse(url)?.hasScheme == true ? url : 'https://$url';

  /// Short id for a strategy name.
  static String strategyId(String? strategyName) {
    final lower = strategyName.orEmpty().toLowerCase();
    return strategyIds.firstWhere(lower.contains, orElse: () => 'unknown');
  }

  Map<String, dynamic> toPayload() => {
    'channel': channel.name,
    'strategy': strategy,
    'outcome': outcome,
    'success': success,
    'fromCache': fromCache,
    'parseTimeMs': parseTimeMs,
    'url': ?url,
    'successfulTier': ?successfulTier,
    'parserVersion': ?parserVersion,
    'finalQuality': ?finalQuality,
    'usedLlm': usedLlm,
    'estimatedCostUsd': ?estimatedCostUsd,
    'errorCode': ?errorCode,
    'tierAttempts': ?tierAttempts,
    if (unknownDomain) 'unknownDomain': true,
  };
}
