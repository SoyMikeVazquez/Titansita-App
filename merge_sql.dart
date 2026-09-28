import 'dart:io';

void main() {
  final insertFile = File('ejercicios_rows.sql');
  final updateFile = File('actualizar_ejercicios_espanol.sql');
  final outputFile = File('insertar_final_espanol_con_gifs.sql');

  if (!insertFile.existsSync() || !updateFile.existsSync()) {
    print('Faltan archivos.');
    return;
  }

  // 1. Extraer los image_url del archivo ejercicios_rows.sql
  // El archivo tiene el formato: INSERT INTO ... VALUES ('id', 'created_at', 'name', 'description', 'image_url', 'categoria'), ('id2'...)
  final insertContent = insertFile.readAsStringSync();
  
  // Expresión regular para extraer los valores dentro de los paréntesis (...)
  // \('([^']*)', '([^']*)', '([^']*)', '([^']*)', '([^']*)', '([^']*)'\)
  final RegExp regex = RegExp(r"\('([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)");
  
  final Map<String, String> idToImageUrl = {};
  
  for (final match in regex.allMatches(insertContent)) {
    final id = match.group(1)!;
    final imageUrl = match.group(5)!;
    idToImageUrl[id] = imageUrl;
  }
  
  print('Encontrados ${idToImageUrl.length} image_urls en ejercicios_rows.sql');

  // 2. Leer actualizar_ejercicios_espanol.sql y generar los INSERTS finales
  final updateLines = updateFile.readAsLinesSync();
  final outLines = <String>[];
  
  outLines.add('-- SCRIPT DE INSERCIÓN MASIVA DE EJERCICIOS CON GIFS Y TRADUCCIONES AL ESPAÑOL');
  outLines.add('-- Ejecuta este archivo en el SQL Editor de Supabase (elimina los existentes antes si lo deseas)');
  outLines.add('');

  int missingGifs = 0;

  for (final line in updateLines) {
    if (line.trim().isEmpty || line.startsWith('--')) {
      outLines.add(line);
      continue;
    }

    if (line.startsWith('UPDATE public.ejercicios SET')) {
      final nameMatch = RegExp(r"name = '(.*?)'").firstMatch(line);
      final catMatch = RegExp(r"categoria = '(.*?)'").firstMatch(line);
      final descMatch = RegExp(r"description = '(.*?)'").firstMatch(line);
      final idMatch = RegExp(r"id = '(.*?)'").firstMatch(line);

      if (nameMatch != null && catMatch != null && descMatch != null && idMatch != null) {
        final name = nameMatch.group(1)?.replaceAll("'", "''") ?? '';
        final cat = catMatch.group(1)?.replaceAll("'", "''") ?? '';
        final desc = descMatch.group(1)?.replaceAll("'", "''") ?? '';
        final id = idMatch.group(1) ?? '';

        final imageUrl = idToImageUrl[id];
        
        if (imageUrl != null) {
          outLines.add("INSERT INTO public.ejercicios (id, name, categoria, description, image_url) VALUES ('$id', '$name', '$cat', '$desc', '$imageUrl');");
        } else {
          missingGifs++;
          outLines.add("INSERT INTO public.ejercicios (id, name, categoria, description) VALUES ('$id', '$name', '$cat', '$desc');");
        }
      } else {
        outLines.add(line);
      }
    } else {
      outLines.add(line);
    }
  }

  outputFile.writeAsStringSync(outLines.join('\n'));
  print('Convertido exitosamente en insertar_final_espanol_con_gifs.sql');
  print('Faltaron GIFs para $missingGifs ejercicios (seguramente no estaban en ejercicios_rows.sql)');
}
