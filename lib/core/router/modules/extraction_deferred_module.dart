import 'package:flutter/material.dart';
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/constants/routes.dart';

// Deferred imports for extraction views
import 'package:butlery/views/import_via_url_view.dart' deferred as import_url;
import 'package:butlery/views/smart_import_view.dart' deferred as smart_import;
import 'package:butlery/views/photo_import_view.dart' deferred as photo_import;
import 'package:butlery/views/voice_import_view.dart' deferred as voice_import;
import 'package:butlery/views/file_import_view.dart' deferred as file_import;
import 'package:butlery/views/importera_fran_arkiv_view.dart'
    deferred as arkiv_import;

/// Deferred module for extraction/import related views
/// This module defers loading of:
/// - ImportViaUrlView
/// - SmartImportView
/// - PhotoImportView
/// - FileImportView
/// - ImporteraFranArkivView
class ExtractionDeferredModule implements DeferredModule {
  bool _isLoaded = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Set<String> get handledRoutes => {
    Routes.importViaUrl,
    Routes.smartImport,
    Routes.photoImport,
    Routes.voiceImport,
    Routes.fileImport,
    Routes.importFromArchive,
  };

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    // Load all extraction view libraries in parallel
    try {
      await Future.wait([
        import_url.loadLibrary(),
        smart_import.loadLibrary(),
        photo_import.loadLibrary(),
        voice_import.loadLibrary(),
        file_import.loadLibrary(),
        arkiv_import.loadLibrary(),
      ]);
    } on Exception catch (e) {
      throw StateError(
        'ExtractionDeferredModule: deferred library load failed: $e',
      );
    }

    _isLoaded = true;
  }

  @override
  Widget buildRoute(String routeName, RouteSettings settings) {
    switch (routeName) {
      case Routes.importViaUrl:
        return import_url.ImportViaUrlView();

      case Routes.smartImport:
        // A String argument is a URL shared into the app (web-share) to prefill.
        return smart_import.SmartImportView(
          initialUrl: settings.arguments is String
              ? settings.arguments as String
              : null,
        );

      case Routes.photoImport:
        // BUT-941: a List<String> argument is photo paths shared into the app
        // via the OS share sheet — seed them as import pages.
        return photo_import.PhotoImportView(
          initialImagePaths: settings.arguments is List<String>
              ? settings.arguments as List<String>
              : null,
        );

      case Routes.voiceImport:
        return voice_import.VoiceImportView();

      case Routes.fileImport:
        return file_import.FileImportView();

      case Routes.importFromArchive:
        return arkiv_import.ImporteraFranArkivView();

      default:
        throw ArgumentError('Unknown extraction route: $routeName');
    }
  }
}
