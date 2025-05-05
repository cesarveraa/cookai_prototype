// pubspec.yaml dependencies:
// Add the following under dependencies in your pubspec.yaml:
//
//   flutter:
//     sdk: flutter
//   image_picker: ^0.8.6
//   http: ^0.13.4

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Llama 4 Vision Maverick',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.grey[50],
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _image;
  bool _loading = false;
  String? _contentText; // stores the AI message content
  String? _rawResponse;
  final ImagePicker _picker = ImagePicker();

  static const String _apiKey = 'f7841902-6ddd-46ea-bf2c-59eaab1bb17f';
  static const String _baseUrl = 'https://api.sambanova.ai/v1/chat/completions';

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _setImage(picked));
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _setImage(picked));
  }

  void _setImage(XFile picked) {
    _image = picked;
    _contentText = null;
    _rawResponse = null;
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      final bytes = await File(_image!.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:image/${_image!.path.split('.').last};base64,$base64Image';

      final promptText = '''
Identifica todos los ingredientes de la imagen con su nombre y cantidad aproximada (peso o volumen). Indica para cuántas porciones alcanza y clasifica el tipo de plato (entrante, principal, postre, snack). Proporciona las propiedades nutricionales por porción: calorías, proteínas, grasas, carbohidratos, fibra y vitaminas principales. Sugiere al menos dos recetas que puedan prepararse con estos ingredientes, incluyendo pasos breves de preparación. Añade consejos de conservación y posibles variaciones o sustituciones de ingredientes.''';

      final payload = {
        'model': 'Llama-4-Maverick-17B-128E-Instruct',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': promptText},
              {'type': 'image_url', 'image_url': {'url': dataUri}}
            ]
          }
        ],
        'temperature': 0.2,
        'top_p': 0.3
      };

      print('🔹 Enviando payload: $payload');
      final resp = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(payload),
      );

      print('🔹 Response status: ${resp.statusCode}');
      print('🔹 Response body: ${resp.body}');
      _rawResponse = resp.body;

      if (resp.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(resp.body);
        // Extract the assistant message
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          setState(() {
            _contentText = content;
          });
        }
      } else {
        throw Exception('Status ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ Error en solicitud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Llama 4 Vision Maverick'), centerTitle: true),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_image!.path), height: 240, fit: BoxFit.cover),
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: Icon(Icons.photo_library),
                        label: Text('Galería'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: Icon(Icons.camera_alt),
                        label: Text('Cámara'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _analyzeImage,
                  icon: Icon(Icons.analytics),
                  label: Text('Analizar Imagen'),
                ),
                if (_loading) ...[
                  SizedBox(height: 20),
                  Center(child: CircularProgressIndicator()),
                ],
                if (_contentText != null) ...[
                  SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        _contentText!,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
                if (!_loading && _contentText == null && _rawResponse != null) ...[
                  SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Respuesta cruda de la API:\n\n$_rawResponse',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
