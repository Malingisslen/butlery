class UploadConstants {
  static const int maxRecipeImageBytes = 5 * 1024 * 1024;
  static const int maxPreCompressionBytes = 20 * 1024 * 1024;
  static const int maxMessagingImageBytes = 10 * 1024 * 1024;
  static const int maxScreenshotBytes = 5 * 1024 * 1024;
  static const int maxOcrImageBytes = 10 * 1024 * 1024;

  /// Largest binary page the AI reader accepts. The ocr-recipe-image Cloud
  /// Function rejects base64 longer than 10 * 1024 * 1024 characters, and
  /// base64 is 4/3 the binary size, so the page must stay under 7.5 MB or the
  /// user waits for an upload the server then refuses.
  static const int maxAiReaderPageBytes = 10 * 1024 * 1024 * 3 ~/ 4;
  static const int maxStorageFileBytes = 10 * 1024 * 1024;
  static const int skipCompressionThreshold = 500 * 1024;
  static const int compressionTargetBytes = 1024 * 1024;
  static const int minOcrImageBytes = 50 * 1024;
}
