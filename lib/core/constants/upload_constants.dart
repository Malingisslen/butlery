class UploadConstants {
  static const int maxRecipeImageBytes = 5 * 1024 * 1024;
  static const int maxPreCompressionBytes = 20 * 1024 * 1024;
  static const int maxMessagingImageBytes = 10 * 1024 * 1024;
  static const int maxScreenshotBytes = 5 * 1024 * 1024;
  static const int maxOcrImageBytes = 10 * 1024 * 1024;
  static const int maxStorageFileBytes = 10 * 1024 * 1024;
  static const int skipCompressionThreshold = 500 * 1024;
  static const int compressionTargetBytes = 1024 * 1024;
  static const int minOcrImageBytes = 50 * 1024;
}
