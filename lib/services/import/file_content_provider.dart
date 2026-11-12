import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Abstraction for file content provision to enable dependency injection and testing
abstract class FileContentProvider {
  /// Pick a single file using the platform file picker; null when cancelled.
  Future<PlatformFile?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  });

  /// Import from raw content for testing
  Future<PlatformFile?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  );
}

/// Default implementation using FilePicker
class DefaultFileContentProvider implements FileContentProvider {
  @override
  Future<PlatformFile?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    return await FilePicker.pickFile(
      type: type,
      allowedExtensions: allowedExtensions,
    );
  }

  @override
  Future<PlatformFile?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  ) async {
    return InMemoryPlatformFile(
      name: fileName,
      bytes: content,
      extension: extension,
    );
  }
}

/// A [PlatformFile] backed by bytes already in memory; the package ships no
/// concrete one and `PlatformFile` is a base class, so tests and
/// [DefaultFileContentProvider.provideContent] need this subclass.
final class InMemoryPlatformFile extends PlatformFile {
  InMemoryPlatformFile({
    required this.name,
    required Uint8List bytes,
    String? extension,
  }) : _bytes = bytes,
       _extension = extension;

  final Uint8List _bytes;
  final String? _extension;

  @override
  final String name;

  @override
  String? get extension => _extension;

  @override
  Uri get uri => Uri.dataFromBytes(_bytes);

  // cross_file is not a direct dependency; image_picker re-exports XFile.
  @override
  XFile get xFile => XFile.fromData(_bytes, name: name);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}
