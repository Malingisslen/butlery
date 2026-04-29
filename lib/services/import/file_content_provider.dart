import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Abstraction for file content provision to enable dependency injection and testing
abstract class FileContentProvider {
  /// Pick files using platform file picker
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = true,
    bool withReadStream = false,
  });

  /// Import from raw content for testing
  Future<FilePickerResult?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  );
}

/// Default implementation using FilePicker
class DefaultFileContentProvider implements FileContentProvider {
  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = true,
    bool withReadStream = false,
  }) async {
    return await FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
      withReadStream: withReadStream,
    );
  }

  @override
  Future<FilePickerResult?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  ) async {
    // Create a mock FilePickerResult with the provided content
    // This is for testing purposes
    return _MockFilePickerResult(
      files: [
        _MockPlatformFile(
          name: fileName,
          bytes: content,
          size: content.length,
          extension: extension,
        ),
      ],
    );
  }
}

/// Mock FilePickerResult for testing
class _MockFilePickerResult extends FilePickerResult {
  _MockFilePickerResult({required List<PlatformFile> files}) : super(files);
}

/// Mock PlatformFile for testing
class _MockPlatformFile extends PlatformFile {
  final String? _extension;

  _MockPlatformFile({
    required super.name,
    required super.size,
    super.bytes,
    String? extension,
  }) : _extension = extension;

  @override
  String? get extension => _extension;
}
