import 'package:butlery/services/import/utilities/html_utilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const page = 'https://example.se/recept/pannkakor';

  group('HtmlUtilities.extractOgImage', () {
    test('reads an https og:image', () {
      const html =
          '<head><meta property="og:image" content="https://cdn.example.se/a.jpg"></head>';
      expect(
        HtmlUtilities.extractOgImage(html, page),
        'https://cdn.example.se/a.jpg',
      );
    });

    test('works with content before property and single quotes', () {
      const html =
          "<meta content='https://cdn.example.se/b.jpg' property='og:image'>";
      expect(
        HtmlUtilities.extractOgImage(html, page),
        'https://cdn.example.se/b.jpg',
      );
    });

    test('resolves a relative path against the page', () {
      const html = '<meta property="og:image" content="/img/c.jpg">';
      expect(
        HtmlUtilities.extractOgImage(html, page),
        'https://example.se/img/c.jpg',
      );
    });

    test('decodes &amp; in the address', () {
      const html =
          '<meta property="og:image" content="https://x.se/i.jpg?a=1&amp;b=2">';
      expect(
        HtmlUtilities.extractOgImage(html, page),
        'https://x.se/i.jpg?a=1&b=2',
      );
    });

    test('refuses plain http, also after resolving', () {
      const html = '<meta property="og:image" content="http://x.se/i.jpg">';
      expect(HtmlUtilities.extractOgImage(html, page), isNull);
      expect(HtmlUtilities.extractOgImage(html, 'http://example.se/p'), isNull);
    });

    test('refuses non-web schemes', () {
      const html =
          '<meta property="og:image" content="javascript:alert(1)">'
          '<meta property="og:image" content="data:image/png;base64,AAAA">';
      expect(HtmlUtilities.extractOgImage(html, page), isNull);
    });

    test('skips a bad tag and takes a later good one', () {
      const html =
          '<meta property="og:image" content="http://x.se/a.jpg">'
          '<meta property="og:image" content="https://x.se/b.jpg">';
      expect(HtmlUtilities.extractOgImage(html, page), 'https://x.se/b.jpg');
    });

    test('accepts secure_url, name=, upper case and protocol-relative', () {
      expect(
        HtmlUtilities.extractOgImage(
          '<meta property="og:image:secure_url" content="https://x.se/s.jpg">',
          page,
        ),
        'https://x.se/s.jpg',
      );
      expect(
        HtmlUtilities.extractOgImage(
          '<meta name="og:image" content="https://x.se/n.jpg">',
          page,
        ),
        'https://x.se/n.jpg',
      );
      expect(
        HtmlUtilities.extractOgImage(
          '<META PROPERTY="OG:IMAGE" CONTENT="https://x.se/u.jpg">',
          page,
        ),
        'https://x.se/u.jpg',
      );
      expect(
        HtmlUtilities.extractOgImage(
          '<meta property="og:image" content="//cdn.x.se/p.jpg">',
          page,
        ),
        'https://cdn.x.se/p.jpg',
      );
    });

    test('is null when the page has no og:image', () {
      const html = '<meta property="og:title" content="Pannkakor">';
      expect(HtmlUtilities.extractOgImage(html, page), isNull);
    });
  });
}
