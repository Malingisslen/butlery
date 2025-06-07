// lib/views/photo_import_view.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../widgets/action_button.dart';
import '../theme/app_theme.dart';

/// ✨ 100% THEME-CENTRALISERAD FOTO-OCR VY
class PhotoImportView extends StatefulWidget {
  const PhotoImportView({super.key});

  @override
  State<PhotoImportView> createState() => _PhotoImportViewState();
}

class _PhotoImportViewState extends State<PhotoImportView> {
  File? _imageFile;
  Uint8List? _imageBytes;
  bool _loading = false;
  String _ocrText = '';
  String? _error;

  Future<void> _pickAndRecognize() async {
    setState(() {
      _ocrText = '';
      _error = null;
      _loading = true;
    });

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) {
      setState(() => _loading = false);
      return;
    }

    final bytes = await picked.readAsBytes();
    if (kIsWeb) {
      _imageBytes = bytes;
      _imageFile = null;
    } else {
      _imageFile = File(picked.path);
      _imageBytes = null;
    }

    // 1) Kör OCR
    final base64Image = base64Encode(bytes);
    String text = await _callOcrApi(base64Image, engine: '2');
    if (text.isEmpty) {
      text = await _callOcrApi(
        base64Image,
        engine: '1',
        extras: {'detectOrientation': 'true'},
      );
    }

    // 2) Uppdatera UI
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (text.isEmpty) {
        _error =
            'Inga resultat tolkades. Kontrollera ljus, fokus eller vinkel.';
      } else {
        _ocrText = text;
      }
    });
  }

  Future<String> _callOcrApi(
    String base64Image, {
    required String engine,
    Map<String, String>? extras,
  }) async {
    final body = <String, String>{
      'base64Image': 'data:image/png;base64,$base64Image',
      'language': 'swe',
      'isOverlayRequired': 'false',
      'OCREngine': engine,
    };
    if (extras != null) body.addAll(extras);

    try {
      final response = await http.post(
        Uri.parse('https://api.ocr.space/parse/image'),
        headers: {
          'apikey': 'K86932882588957',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      final decoded = jsonDecode(response.body);
      final List<dynamic>? parsed = decoded['ParsedResults'];
      if (parsed != null && parsed.isNotEmpty) {
        return parsed[0]['ParsedText'] as String? ?? '';
      }
    } catch (_) {
      // ignore
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Container(
      height: AppTheme.imageHeightMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: AppTheme.iconSizeHero, // ✅ SEMANTISK STORLEK
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            AppTheme.smallGap, // ✅ SEMANTISK GAP
            Text(
              'Ingen bild vald',
              style: AppTheme.subtitleStyle, // ✅ SEMANTISK STYLE
            ),
          ],
        ),
      ),
    );

    if (_loading) {
      imageWidget = Container(
        height: AppTheme.imageHeightMedium,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
        ),
        child: Center(
          child: AppTheme.mediumLoadingIndicator(), // ✅ SEMANTISK LOADING
        ),
      );
    } else if (_imageBytes != null) {
      imageWidget = ClipRRect(
        borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
        child: Image.memory(
          _imageBytes!,
          height: AppTheme.imageHeightMedium,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (_imageFile != null) {
      imageWidget = ClipRRect(
        borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
        child: Image.file(
          _imageFile!,
          height: AppTheme.imageHeightMedium,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Foto-OCR')),
      body: Padding(
        padding: AppTheme.screenPadding, // ✅ SEMANTISK PADDING
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ActionButton.primary(
              label: 'Ta bild & tolka',
              icon: Icons.camera_alt,
              onPressed: _loading ? null : _pickAndRecognize,
              isExpanded: true,
            ),
            AppTheme.mediumGap, // ✅ SEMANTISK GAP
            imageWidget,
            AppTheme.mediumGap, // ✅ SEMANTISK GAP
            // Error container med semantisk widget ✨
            if (_error != null) ...[
              AppTheme.errorContainer(context, _error!), // ✅ SEMANTISK WIDGET
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
            ],

            // Om vi fick text tillbaka, visa förhandsgranskning + knappen
            if (_ocrText.isNotEmpty) ...[
              Text(
                'Tolkad text:',
                style: AppTheme.sectionTitleStyle, // ✅ SEMANTISK STYLE
              ),
              AppTheme.smallGap, // ✅ SEMANTISK GAP
              Expanded(
                flex: 2,
                child: Container(
                  padding: AppTheme.cardPadding, // ✅ SEMANTISK PADDING
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: AppTheme.mediumRadius, // ✅ SEMANTISK RADIUS
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _ocrText,
                      style:
                          Theme.of(
                            context,
                          ).textTheme.bodyMedium, // ✅ THEME TYPOGRAPHY
                    ),
                  ),
                ),
              ),
              AppTheme.mediumGap, // ✅ SEMANTISK GAP
              ActionButton.primary(
                label: 'Gå vidare till redigera',
                onPressed: () {
                  // 3) Navigera till sociala-medier-vyn med OCR-texten
                  Navigator.pushNamed(
                    context,
                    '/franSocialaMedier',
                    arguments: _ocrText,
                  );
                },
                isExpanded: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
