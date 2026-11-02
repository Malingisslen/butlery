import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';

/// Shortens through whichever [DeepLinkService] is registered when the link is
/// asked for, and hands the long link back untouched when none is.
Future<String> shortUrlFromLocator(String longUrl) async {
  final deepLinks = ServiceLocator.tryGet<DeepLinkService>();
  return deepLinks == null ? longUrl : deepLinks.generateShortUrl(longUrl);
}

/// Drops blocked people from a share through whichever [BlockedUserFilter] is
/// registered when the share runs; see [BlockedUserFilter.filterShareRecipients]
/// for what happens when none is.
Future<List<String>> shareRecipientsFromLocator(List<String> recipientIds) =>
    BlockedUserFilter.filterShareRecipients(
      ServiceLocator.tryGet<BlockedUserFilter>(),
      recipientIds,
    );
