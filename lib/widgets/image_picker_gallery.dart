// 📦 widgets/image_picker_gallery.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerGallery extends StatelessWidget {
  final List<String> imageUrls;
  final Function(List<XFile>) onImagesPicked;
  final Function(int) onRemoveImage;

  const ImagePickerGallery({
    super.key,
    required this.imageUrls,
    required this.onImagesPicked,
    required this.onRemoveImage,
  });

  Future<void> _pickImages(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      onImagesPicked(images);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(imageUrls.length, (index) {
            return Stack(
              children: [
                Image.network(
                  imageUrls[index],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => onRemoveImage(index),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _pickImages(context),
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Lägg till bilder'),
        ),
      ],
    );
  }
}
