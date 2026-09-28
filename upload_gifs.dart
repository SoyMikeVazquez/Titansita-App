import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String supabaseUrl = 'https://ffbjqwvadxnqrbxnysjl.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmYmpxd3ZhZHhucXJieG55c2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEwODY5MzksImV4cCI6MjA3NjY2MjkzOX0.sH2yt0Yfi1z4sdUSlSi8LEcVbQHYw-N7bZqOQYjUIX0';

// List of words to keep in lowercase in titles (Spanish/Portuguese prepositions/conjunctions)
const Set<String> _lowercaseWords = {'y', 'o', 'e', 'u', 'de', 'del', 'la', 'las', 'el', 'los', 'con', 'para', 'com', 'da', 'do', 'dos', 'das'};

String _toTitleCase(String text) {
  if (text.isEmpty) return '';
  
  // Replace multiple spaces/underscores/hyphens with a single space
  final cleanText = text
      .replaceAll(RegExp(r'[\s\-_]+'), ' ')
      .trim();
      
  final words = cleanText.split(' ');
  final List<String> result = [];
  
  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    
    final lowerWord = word.toLowerCase();
    
    // Capitalize first word, last word, or any word not in the lowercase exceptions list
    if (i == 0 || i == words.length - 1 || !_lowercaseWords.contains(lowerWord)) {
      result.add(word[0].toUpperCase() + word.substring(1).toLowerCase());
    } else {
      result.add(lowerWord);
    }
  }
  
  return result.join(' ');
}

void main(List<String> args) async {
  print('=== IMPORTADOR AUTOMÁTICO DE EJERCICIOS A SUPABASE ===\n');

  final directoryPath = './exercise_gifs';
  final dir = Directory(directoryPath);

  if (!await dir.exists()) {
    print('Error: La carpeta "$directoryPath" no existe.');
    print('Por favor, crea una carpeta llamada "exercise_gifs" en la raíz del proyecto.');
    exit(1);
  }

  // Find all .gif, .png, .jpg, .jpeg files recursively
  final List<FileSystemEntity> entities = dir.listSync(recursive: true);
  final List<File> files = [];

  for (final entity in entities) {
    if (entity is File) {
      final pathLower = entity.path.toLowerCase();
      if (pathLower.endsWith('.gif') ||
          pathLower.endsWith('.png') ||
          pathLower.endsWith('.jpg') ||
          pathLower.endsWith('.jpeg')) {
        files.add(entity);
      }
    }
  }

  if (files.isEmpty) {
    print('No se encontraron archivos de imagen/GIF en la carpeta "$directoryPath" ni en sus subcarpetas.');
    exit(0);
  }

  print('Se encontraron ${files.length} archivos para importar.');

  String activeToken = supabaseAnonKey;
  String? email;
  String? password;
  bool skipAuth = args.contains('--no-auth');

  if (!skipAuth) {
    // Check if credentials are provided in command line arguments
    if (args.length >= 2) {
      email = args[0];
      password = args[1];
    } else {
      // Prompt the user in case they want to log in
      print('\nPara insertar los ejercicios en la base de datos se requiere autenticación de entrenador.');
      stdout.write('Email del Entrenador: ');
      email = stdin.readLineSync()?.trim();
      stdout.write('Contraseña: ');
      password = stdin.readLineSync()?.trim();
    }
  }

  if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
    try {
      print('Iniciando sesión en Supabase...');
      final loginUrl = Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password');
      final response = await http.post(
        loginUrl,
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        activeToken = data['access_token'] ?? supabaseAnonKey;
        print('Sesión iniciada con éxito.\n');
      } else {
        print('Error de autenticación (${response.statusCode}): ${response.body}');
        print('Intentando continuar de forma anónima (puede fallar si RLS está activo)...');
      }
    } catch (e) {
      print('Error de conexión: $e. Intentando continuar de forma anónima...');
    }
  } else {
    print('No se ingresaron credenciales. Intentando continuar de forma anónima...\n');
  }

  int successCount = 0;

  for (int i = 0; i < files.length; i++) {
    final file = files[i];
    final fileUri = file.uri;
    final fileName = fileUri.pathSegments.last;

    // Detect category from parent folder name
    final parentDirSegmentIndex = fileUri.pathSegments.length - 2;
    String rawCategory = 'General';
    if (parentDirSegmentIndex >= 0) {
      final parentName = fileUri.pathSegments[parentDirSegmentIndex];
      if (parentName != 'exercise_gifs') {
        rawCategory = parentName;
      }
    }

    // Format category: Title Case (e.g. "ABDOMEN CORE" -> "Abdomen Core")
    final String formattedCategory = _toTitleCase(rawCategory);

    // Format exercise name: remove file extensions, numbers in parentheses, hyphens, underscores
    var cleanFileName = fileName
        .replaceAll(RegExp(r'\.gif$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\.png$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\.jpg$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\.jpeg$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(\d+\)'), '') // Removes e.g. "(1)", "(2)"
        .trim();

    final String finalName = _toTitleCase(cleanFileName);
    final String description = 'Ejercicio de $formattedCategory - Importado automáticamente de $fileName';

    print('[${i + 1}/${files.length}] [$formattedCategory] "$finalName"...');

    try {
      // 1. Upload to storage (sanitize filename for Supabase Storage compatibility)
      final cleanExt = fileName.toLowerCase().endsWith('.gif') ? '.gif' : '.jpg';
      final safeBaseName = cleanFileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final storageFileName = 'exercises/${DateTime.now().millisecondsSinceEpoch}_$safeBaseName$cleanExt';
      final bytes = await file.readAsBytes();
      
      final uploadUrl = Uri.parse('$supabaseUrl/storage/v1/object/general/$storageFileName');
      final uploadResponse = await http.post(
        uploadUrl,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $activeToken',
          'Content-Type': fileName.toLowerCase().endsWith('.gif') ? 'image/gif' : 'image/jpeg',
          'x-upsert': 'true',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Error en Storage (${uploadResponse.statusCode}): ${uploadResponse.body}');
      }

      final publicUrl = '$supabaseUrl/storage/v1/object/public/general/$storageFileName';

      // 2. Insert into "ejercicios" table with upsert (merge-duplicates on name)
      final dbUrl = Uri.parse('$supabaseUrl/rest/v1/ejercicios?on_conflict=name');
      final dbResponse = await http.post(
        dbUrl,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $activeToken',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({
          'name': finalName,
          'description': description,
          'image_url': publicUrl,
          'categoria': formattedCategory,
        }),
      );

      if (dbResponse.statusCode != 201 && dbResponse.statusCode != 200) {
        throw Exception('Error en BD (${dbResponse.statusCode}): ${dbResponse.body}');
      }

      print('   -> ¡ÉXITO! Vinculado en Supabase.');
      successCount++;
    } catch (e) {
      print('   -> ERROR: $e');
    }
  }

  print('\n========================================');
  print('IMPORTACIÓN FINALIZADA.');
  print('Ejercicios creados con éxito: $successCount de ${files.length}');
  print('========================================');
  exit(0);
}
