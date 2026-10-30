import 'package:butlery/core/utils/external_link.dart';

const _storageHosts = {
  'firebasestorage.googleapis.com',
  'storage.googleapis.com',
};

// Bucket names are global, so a prefix would let anyone's `butlery-…` bucket
// pass as ours; only the app's own buckets count.
const _ownBuckets = {
  'butlery-prod.firebasestorage.app',
  'butlery-app-staging.firebasestorage.app',
};

/// True when [url] points into one of Butlery's own Storage buckets, as a
/// Firebase download URL (`/v0/b/<bucket>/o/…`) or a signed GCS URL
/// (`/<bucket>/…`). Matching the host AND the bucket keeps a third-party URL
/// that merely contains `/o/users%2F` from passing as ours.
bool isOwnStorageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  if (!_storageHosts.contains(uri.host)) return false;
  final segments = uri.pathSegments;
  final bucket = uri.host == 'firebasestorage.googleapis.com'
      ? (segments.length > 2 && segments[0] == 'v0' && segments[1] == 'b'
            ? segments[2]
            : null)
      : (segments.isNotEmpty ? segments.first : null);
  return _ownBuckets.contains(bucket);
}

/// True when [imageUrl] was taken from the web page the recipe was imported
/// from rather than uploaded by the user. Such an image is shown from the
/// original site with its source named, and is never copied into Storage.
bool isBorrowedImage({required String imageUrl, String? sourceUrl}) {
  if (!isSafeExternalUrl(sourceUrl)) return false;
  if (!isSafeExternalUrl(imageUrl)) return false;
  return !isOwnStorageUrl(imageUrl);
}

/// The site name shown for [sourceUrl]: its host without a leading `www.`
/// or `m.`. Null when [sourceUrl] is not a safe http(s) URL.
String? sourceSiteName(String? sourceUrl) {
  if (!isSafeExternalUrl(sourceUrl)) return null;
  final host = Uri.parse(sourceUrl!).host.toLowerCase();
  return host.replaceFirst(RegExp(r'^(www\.|m\.)'), '');
}
