import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/borrowed_image.dart';

void main() {
  const source = 'https://www.matbloggen.se/recept/laxpudding';
  const ownDownload =
      'https://firebasestorage.googleapis.com/v0/b/butlery-prod.firebasestorage.app/o/users%2Fu1%2Frecipes%2Fa.jpg?alt=media&token=t';
  const ownSigned =
      'https://storage.googleapis.com/butlery-prod.firebasestorage.app/users/u1/recipes/a.jpg?GoogleAccessId=x&Expires=1&Signature=s';

  group('isOwnStorageUrl', () {
    test('accepts Butlery download and signed URLs', () {
      expect(isOwnStorageUrl(ownDownload), isTrue);
      expect(isOwnStorageUrl(ownSigned), isTrue);
    });

    test('rejects a foreign host whose path looks like ours', () {
      expect(
        isOwnStorageUrl('https://evil.example/o/users%2Fu1%2Fa.jpg'),
        isFalse,
      );
      expect(
        isOwnStorageUrl(
          'https://evil.example/v0/b/butlery-prod/o/users%2Fa.jpg',
        ),
        isFalse,
      );
    });

    test('rejects another project bucket on the Storage hosts', () {
      expect(
        isOwnStorageUrl(
          'https://firebasestorage.googleapis.com/v0/b/receptsajt.appspot.com/o/a.jpg',
        ),
        isFalse,
      );
      expect(
        isOwnStorageUrl('https://storage.googleapis.com/cdn-receptsajt/a.jpg'),
        isFalse,
      );
      // A stranger's bucket that merely starts with our name.
      expect(
        isOwnStorageUrl(
          'https://firebasestorage.googleapis.com/v0/b/butlery-x/o/a.jpg',
        ),
        isFalse,
      );
      expect(
        isOwnStorageUrl('https://storage.googleapis.com/butlery-x/a.jpg'),
        isFalse,
      );
    });

    test('rejects http and junk', () {
      expect(
        isOwnStorageUrl(ownDownload.replaceFirst('https', 'http')),
        isFalse,
      );
      expect(isOwnStorageUrl('inte en adress'), isFalse);
      expect(isOwnStorageUrl(''), isFalse);
    });
  });

  group('isBorrowedImage', () {
    test('an image from the web page of a web-imported recipe is borrowed', () {
      expect(
        isBorrowedImage(
          imageUrl: 'https://matbloggen.se/bilder/lax.jpg',
          sourceUrl: source,
        ),
        isTrue,
      );
    });

    test('the user\'s own upload is not borrowed, even with a web source', () {
      expect(
        isBorrowedImage(imageUrl: ownDownload, sourceUrl: source),
        isFalse,
      );
      expect(isBorrowedImage(imageUrl: ownSigned, sourceUrl: source), isFalse);
    });

    test('nothing is borrowed without a web source', () {
      const image = 'https://matbloggen.se/bilder/lax.jpg';
      expect(isBorrowedImage(imageUrl: image), isFalse);
      expect(
        isBorrowedImage(imageUrl: image, sourceUrl: 'Butlerys receptsamling'),
        isFalse,
      );
    });

    test('a local file path is not borrowed', () {
      expect(
        isBorrowedImage(imageUrl: '/data/user/0/bild.jpg', sourceUrl: source),
        isFalse,
      );
    });
  });

  group('sourceSiteName', () {
    test('drops www. and m. and lower-cases the host', () {
      expect(sourceSiteName(source), 'matbloggen.se');
      expect(sourceSiteName('https://m.Koket.se/x'), 'koket.se');
      expect(sourceSiteName('https://recept.arla.se/x'), 'recept.arla.se');
    });

    test('is null for a free-text source', () {
      expect(sourceSiteName('Butlerys receptsamling'), isNull);
      expect(sourceSiteName(null), isNull);
    });
  });
}
