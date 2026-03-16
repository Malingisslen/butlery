import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';

void main() {
  group('HttpContentFetcher.isBlockedHost', () {
    group('blocks private/internal hosts', () {
      test('blocks localhost', () {
        expect(HttpContentFetcher.isBlockedHost('localhost'), isTrue);
        expect(HttpContentFetcher.isBlockedHost('LOCALHOST'), isTrue);
      });

      test('blocks IPv4 loopback (127.0.0.0/8)', () {
        expect(HttpContentFetcher.isBlockedHost('127.0.0.1'), isTrue);
        expect(HttpContentFetcher.isBlockedHost('127.255.255.255'), isTrue);
      });

      test('blocks IPv4 private 10.0.0.0/8', () {
        expect(HttpContentFetcher.isBlockedHost('10.0.0.1'), isTrue);
        expect(HttpContentFetcher.isBlockedHost('10.255.0.1'), isTrue);
      });

      test('blocks IPv4 private 172.16.0.0/12', () {
        expect(HttpContentFetcher.isBlockedHost('172.16.0.1'), isTrue);
        expect(HttpContentFetcher.isBlockedHost('172.31.255.255'), isTrue);
      });

      test('blocks IPv4 private 192.168.0.0/16', () {
        expect(HttpContentFetcher.isBlockedHost('192.168.1.1'), isTrue);
        expect(HttpContentFetcher.isBlockedHost('192.168.0.1'), isTrue);
      });

      test('blocks cloud metadata endpoint (169.254.169.254)', () {
        expect(HttpContentFetcher.isBlockedHost('169.254.169.254'), isTrue);
      });

      test('blocks 0.0.0.0', () {
        expect(HttpContentFetcher.isBlockedHost('0.0.0.0'), isTrue);
      });

      test('blocks IPv6 loopback (::1)', () {
        expect(HttpContentFetcher.isBlockedHost('::1'), isTrue);
      });

      test('blocks empty host', () {
        expect(HttpContentFetcher.isBlockedHost(''), isTrue);
      });
    });

    group('allows public hosts', () {
      test('allows example.com', () {
        expect(HttpContentFetcher.isBlockedHost('example.com'), isFalse);
      });

      test('allows butlery.app', () {
        expect(HttpContentFetcher.isBlockedHost('butlery.app'), isFalse);
      });

      test('allows public IP addresses', () {
        expect(HttpContentFetcher.isBlockedHost('8.8.8.8'), isFalse);
        expect(HttpContentFetcher.isBlockedHost('1.1.1.1'), isFalse);
      });

      test('allows ica.se', () {
        expect(HttpContentFetcher.isBlockedHost('www.ica.se'), isFalse);
      });
    });

    group('edge cases', () {
      test('does not block 172.32.0.1 (outside 172.16-31 range)', () {
        expect(HttpContentFetcher.isBlockedHost('172.32.0.1'), isFalse);
      });

      test('does not block 11.0.0.1 (outside 10.x range)', () {
        expect(HttpContentFetcher.isBlockedHost('11.0.0.1'), isFalse);
      });
    });
  });
}
