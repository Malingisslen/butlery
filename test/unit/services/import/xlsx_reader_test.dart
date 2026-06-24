import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/xlsx_reader.dart';

/// These tests pin the `.xlsx` shapes `XlsxReader` must handle. The
/// `FileImportStrategy` parsing tests cover the inline-string path end-to-end;
/// this file targets the shapes they don't — most importantly the
/// **shared-strings** table (`t="s"`), which is how real Excel, Google Sheets
/// and LibreOffice exports actually store text. A regression here would make
/// real-world imports silently parse blank cells.
void main() {
  group('XlsxReader', () {
    test('reads cells that reference the shared-strings table (t="s")', () {
      final bytes = _xlsx(
        sharedStrings: ['Title', 'Ingredients', 'Pasta', 'Tomato;Basil'],
        sheets: {
          'xl/worksheets/sheet1.xml': [
            [_shared(0), _shared(1)],
            [_shared(2), _shared(3)],
          ],
        },
      );

      final rows = XlsxReader.readFirstSheet(bytes);

      expect(rows, hasLength(2));
      expect(rows[0], equals(['Title', 'Ingredients']));
      expect(rows[1], equals(['Pasta', 'Tomato;Basil']));
    });

    test('pads gaps so cells stay aligned with the header by column ref', () {
      // The middle cell is omitted entirely (B2 missing); the reader must
      // back-fill it from the C2 ref so 'note' lands under the third header.
      final bytes = _xlsx(
        sharedStrings: const [],
        sheets: {
          'xl/worksheets/sheet1.xml': [
            [_inline('A1', 'a'), _inline('B1', 'b'), _inline('C1', 'c')],
            [_inline('A2', 'value'), _inline('C2', 'note')],
          ],
        },
      );

      final rows = XlsxReader.readFirstSheet(bytes);

      expect(rows[1], equals(['value', '', 'note']));
    });

    test('skips an empty leading sheet and returns the first with data', () {
      final bytes = _xlsx(
        sharedStrings: const [],
        sheets: {
          // sheet1 is empty (a pre-seeded default sheet); sheet2 has the data.
          'xl/worksheets/sheet1.xml': const [],
          'xl/worksheets/sheet2.xml': [
            [_inline('A1', 'Real')],
          ],
        },
      );

      final rows = XlsxReader.readFirstSheet(bytes);

      expect(rows, hasLength(1));
      expect(rows.first, equals(['Real']));
    });

    test('returns an empty list when there is no data sheet', () {
      final bytes = _xlsx(
        sharedStrings: const [],
        sheets: {'xl/worksheets/sheet1.xml': const []},
      );

      expect(XlsxReader.readFirstSheet(bytes), isEmpty);
    });
  });
}

// --- minimal .xlsx builders for the test fixtures ---------------------------

/// A raw `<c>` element string, so each test states the exact cell shape.
typedef _Cell = String;

_Cell _shared(int index) => '<c t="s"><v>$index</v></c>';

_Cell _inline(String ref, String text) =>
    '<c r="$ref" t="inlineStr"><is><t>$text</t></is></c>';

Uint8List _xlsx({
  required List<String> sharedStrings,
  required Map<String, List<List<_Cell>>> sheets,
}) {
  final archive = Archive();

  if (sharedStrings.isNotEmpty) {
    final si = sharedStrings.map((s) => '<si><t>$s</t></si>').join();
    archive.addFile(
      ArchiveFile.string(
        'xl/sharedStrings.xml',
        '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/'
            'spreadsheetml/2006/main">$si</sst>',
      ),
    );
  }

  sheets.forEach((name, rows) {
    final body = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      body.write('<row r="${r + 1}">${rows[r].join()}</row>');
    }
    archive.addFile(
      ArchiveFile.string(
        name,
        '<?xml version="1.0"?><worksheet xmlns="http://schemas.'
        'openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
        '$body</sheetData></worksheet>',
      ),
    );
  });

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
