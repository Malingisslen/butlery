import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Minimal `.xlsx` (Office Open XML spreadsheet) reader.
///
/// Replaces the `excel` package (BUT-503), which hard-pinned `archive` to 3.x
/// and so blocked the whole zip/image toolchain from moving forward. An `.xlsx`
/// is just a ZIP of XML; recipe import only needs the first sheet that has data,
/// returned as plain string rows — exactly what this does with `archive` +
/// `xml` (both already direct deps).
class XlsxReader {
  XlsxReader._();

  /// Rows of the first worksheet that contains data, each row a list of trimmed
  /// string cell values. Gaps are filled with `''` so cells stay aligned with
  /// the header row (column index is derived from each cell's `A1`-style ref).
  /// Returns an empty list if the workbook has no data sheet.
  static List<List<String>> readFirstSheet(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final shared = _sharedStrings(archive);

    // Worksheets live at xl/worksheets/sheetN.xml. Read in name order and use
    // the first one that actually has rows — mirrors the old excel behaviour,
    // which skipped the empty default sheet a writer may pre-seed.
    final sheets =
        archive.files
            .where(
              (f) =>
                  f.isFile &&
                  f.name.startsWith('xl/worksheets/') &&
                  f.name.endsWith('.xml'),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    for (final sheet in sheets) {
      final rows = _sheetRows(sheet, shared);
      if (rows.isNotEmpty) return rows;
    }
    return const [];
  }

  /// The shared-strings table — string cells reference entries here by index.
  static List<String> _sharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(file.content));
    // A <si> is one string; its text is every descendant <t> concatenated,
    // which also covers rich-text runs (<r><t>…</t></r>).
    return doc
        .findAllElements('si')
        .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
        .toList();
  }

  static List<List<String>> _sheetRows(ArchiveFile file, List<String> shared) {
    final doc = XmlDocument.parse(utf8.decode(file.content));
    final rows = <List<String>>[];
    for (final row in doc.findAllElements('row')) {
      final cells = <String>[];
      for (final c in row.findElements('c')) {
        final col = _columnIndex(c.getAttribute('r').orEmpty());
        while (cells.length < col) {
          cells.add('');
        }
        cells.add(_cellValue(c, shared));
      }
      rows.add(cells);
    }
    return rows;
  }

  static String _cellValue(XmlElement c, List<String> shared) {
    final type = c.getAttribute('t');
    if (type == 'inlineStr') {
      return c.findAllElements('t').map((t) => t.innerText).join().trim();
    }
    final values = c.findElements('v');
    final v = values.isEmpty ? '' : values.first.innerText;
    if (type == 's') {
      final i = int.tryParse(v);
      return (i != null && i >= 0 && i < shared.length) ? shared[i].trim() : '';
    }
    return v.trim();
  }

  /// 0-based column index from a cell ref like `A1`, `C3`, `AA10`.
  static int _columnIndex(String ref) {
    var index = 0;
    for (final code in ref.codeUnits) {
      if (code >= 65 && code <= 90) {
        index = index * 26 + (code - 64);
      } else {
        break;
      }
    }
    return index > 0 ? index - 1 : 0;
  }
}
