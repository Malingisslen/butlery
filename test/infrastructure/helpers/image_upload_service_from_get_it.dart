import 'package:get_it/get_it.dart';

import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';

/// An upload service over the storage service the test registered in GetIt.
ImageUploadService imageUploadServiceFromGetIt() =>
    ImageUploadService(storageService: GetIt.instance<StorageService>());
