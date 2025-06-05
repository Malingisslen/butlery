// lib/views/photo_import_view.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

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
    Widget imageWidget = const SizedBox();
    if (_loading) {
      imageWidget = const Center(child: CircularProgressIndicator());
    } else if (_imageBytes != null) {
      imageWidget = Image.memory(_imageBytes!);
    } else if (_imageFile != null) {
      imageWidget = Image.file(_imageFile!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Foto-OCR')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Ta bild & tolka'),
              onPressed: _loading ? null : _pickAndRecognize,
            ),
            const SizedBox(height: 16),
            Expanded(child: imageWidget),
            const SizedBox(height: 16),

            // Visa fel om nåt gick snett
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],

            // Om vi fick text tillbaka, visa förhandsgranskning + knappen
            if (_ocrText.isNotEmpty) ...[
              Expanded(
                flex: 2,
                child: SingleChildScrollView(child: Text(_ocrText)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Gå vidare till redigera'),
                onPressed: () {
                  // 3) Navigera till sociala-medier-vyn med OCR-texten
                  Navigator.pushNamed(
                    context,
                    '/franSocialaMedier',
                    arguments: _ocrText,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
