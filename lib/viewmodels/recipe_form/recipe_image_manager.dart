// lib/viewmodels/recipe_form/recipe_image_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
// import '../../services/image_picker_service.dart'; // Currently unused
import '../../widgets/image/image_picker_dialogs.dart';
import '../../core/utils/logger.dart';
import '../../core/injection.dart';

/// Manages image operations for recipe forms
class RecipeImageManager extends ChangeNotifier {
  final StorageService _storageService;
  // final ImagePickerService _imagePickerService; // Currently unused

  List<String> _imageUrls = [];
  bool _isUploadingImage = false;
  String? _imageUploadError;

  static const int maxImages = 5;

  RecipeImageManager({
    StorageService? storageService,
    // ImagePickerService? imagePickerService, // Currently unused
  }) : _storageService = storageService ?? sl<StorageService>();
       // _imagePickerService = imagePickerService ?? sl<ImagePickerService>();

  // ===== GETTERS =====

  List<String> get imageUrls => List<String>.from(_imageUrls);
  bool get isUploadingImage => _isUploadingImage;
  String? get imageUploadError => _imageUploadError;
  bool get hasImageUploadError => _imageUploadError != null;
  bool get canAddMoreImages => _imageUrls.length < maxImages;
  int get remainingImageSlots => maxImages - _imageUrls.length;

  // ===== SETTERS =====

  void setImageUrls(List<String> imageUrls) {
    _imageUrls = List<String>.from(imageUrls);
    notifyListeners();
  }

  void addImageUrl(String imageUrl) {
    if (_imageUrls.length < maxImages && !_imageUrls.contains(imageUrl)) {
      _imageUrls.add(imageUrl);
      notifyListeners();
    }
  }

  void removeImageUrl(String imageUrl) {
    _imageUrls.remove(imageUrl);
    notifyListeners();
  }

  void moveImageToFirst(String imageUrl) {
    if (_imageUrls.contains(imageUrl)) {
      _imageUrls.remove(imageUrl);
      _imageUrls.insert(0, imageUrl);
      notifyListeners();
    }
  }

  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < _imageUrls.length && newIndex < _imageUrls.length) {
      final item = _imageUrls.removeAt(oldIndex);
      _imageUrls.insert(newIndex, item);
      notifyListeners();
    }
  }

  // ===== IMAGE OPERATIONS =====

  /// Visa image picker dialog och hantera bildval
  Future<void> showImagePickerDialog(BuildContext context) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _clearImageUploadError();
      
      final result = await ImagePickerDialogs.showImageSourceDialog(context);

      if (result != null) {
        await _processImagePickerResult(result);
      }
    } catch (e) {
      AppLogger.error('Fel vid val av bild: $e');
      _setImageUploadError('Kunde inte välja bild: $e');
    }
  }

  /// Lägg till bild från URL
  Future<void> addImageFromUrl(String imageUrl) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    if (imageUrl.trim().isEmpty) {
      _setImageUploadError('Bildlänk får inte vara tom');
      return;
    }

    try {
      _clearImageUploadError();
      
      // Validera URL format
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null || !uri.hasAbsolutePath) {
        _setImageUploadError('Ogiltig bildlänk');
        return;
      }

      // Kontrollera att bilden inte redan finns
      if (_imageUrls.contains(imageUrl.trim())) {
        _setImageUploadError('Bilden finns redan');
        return;
      }

      addImageUrl(imageUrl.trim());
      AppLogger.info('Bild tillagd från URL: $imageUrl');
    } catch (e) {
      AppLogger.error('Fel vid tillägg av bild från URL: $e');
      _setImageUploadError('Kunde inte lägga till bild: $e');
    }
  }

  /// Ladda upp bild från lokal fil
  Future<void> uploadImageFromFile(XFile imageFile, String recipeId) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _setUploadingImage(true);
      _clearImageUploadError();

      // Convert XFile to File
      final file = File(imageFile.path);
      
      // Ladda upp bilden
      final imageUrl = await _storageService.uploadRecipeImage(file, recipeId);
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        addImageUrl(imageUrl);
        AppLogger.info('Bild uppladdad: $imageUrl');
      } else {
        _setImageUploadError('Kunde inte ladda upp bild');
      }
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av bild: $e');
      _setImageUploadError('Kunde inte ladda upp bild: $e');
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Ladda upp flera bilder från lokala filer
  Future<void> uploadMultipleImages(List<XFile> imageFiles, String recipeId) async {
    if (imageFiles.isEmpty) return;

    final availableSlots = remainingImageSlots;
    final filesToUpload = imageFiles.take(availableSlots).toList();

    if (filesToUpload.length < imageFiles.length) {
      _setImageUploadError('Bara ${filesToUpload.length} av ${imageFiles.length} bilder kunde laddas upp (max $maxImages bilder)');
    }

    try {
      _setUploadingImage(true);
      _clearImageUploadError();

      final uploadFutures = filesToUpload.map((xFile) => 
        _storageService.uploadRecipeImage(File(xFile.path), recipeId)
      ).toList();

      final imageUrls = await Future.wait(uploadFutures);
      
      for (final imageUrl in imageUrls) {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          addImageUrl(imageUrl);
        }
      }

      AppLogger.info('${imageUrls.where((url) => url != null && url.isNotEmpty).length} bilder uppladdade');
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av flera bilder: $e');
      _setImageUploadError('Kunde inte ladda upp bilder: $e');
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Ta bort bild och rensa från storage om det är en uppladdad bild
  Future<void> removeImageAndCleanup(String imageUrl) async {
    try {
      removeImageUrl(imageUrl);
      
      // Om det är en uppladdad bild (inte extern URL), ta bort från storage
      if (imageUrl.contains('firebase') || imageUrl.contains('storage')) {
        await _storageService.deleteRecipeImage(imageUrl);
        AppLogger.info('Bild borttagen från storage: $imageUrl');
      }
    } catch (e) {
      AppLogger.error('Fel vid borttagning av bild: $e');
      // Fortsätt ändå, bilden är borttagen från listan
    }
  }

  /// Rensa alla bilder och cleanup
  Future<void> clearAllImages() async {
    final imagesToRemove = List<String>.from(_imageUrls);
    _imageUrls.clear();
    notifyListeners();

    // Cleanup uploaded images
    for (final imageUrl in imagesToRemove) {
      try {
        if (imageUrl.contains('firebase') || imageUrl.contains('storage')) {
          await _storageService.deleteRecipeImage(imageUrl);
        }
      } catch (e) {
        AppLogger.error('Fel vid rensning av bild: $e');
      }
    }
  }

  // ===== PRIVATE METHODS =====

  /// Bearbeta resultat från image picker
  Future<void> _processImagePickerResult(dynamic result) async {
    if (result is XFile) {
      // Enskild bild
      await uploadImageFromFile(result, 'temp_${DateTime.now().millisecondsSinceEpoch}');
    } else if (result is List<XFile>) {
      // Flera bilder
      await uploadMultipleImages(result, 'temp_${DateTime.now().millisecondsSinceEpoch}');
    } else if (result is String) {
      // URL
      await addImageFromUrl(result);
    }
  }

  void _setUploadingImage(bool uploading) {
    _isUploadingImage = uploading;
    notifyListeners();
  }

  void _setImageUploadError(String error) {
    _imageUploadError = error;
    notifyListeners();
  }

  void _clearImageUploadError() {
    _imageUploadError = null;
    notifyListeners();
  }

  // ===== VALIDATION =====

  /// Validera bildformat
  bool isValidImageFormat(String imageUrl) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final lowercaseUrl = imageUrl.toLowerCase();
    return validExtensions.any((ext) => lowercaseUrl.contains(ext));
  }

  /// Validera bildstorlek (om tillgänglig)
  Future<bool> isValidImageSize(XFile imageFile) async {
    try {
      final fileSize = await imageFile.length();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      return fileSize <= maxSizeInBytes;
    } catch (e) {
      AppLogger.error('Fel vid validering av bildstorlek: $e');
      return true; // Fortsätt om vi inte kan validera
    }
  }

}