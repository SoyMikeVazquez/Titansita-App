import 'dart:io';

void main() {
  final inputFile = File('actualizar_ejercicios_espanol.sql');
  final outputFile = File('insertar_ejercicios_espanol.sql');

  if (!inputFile.existsSync()) {
    print('El archivo no existe.');
    return;
  }

  final lines = inputFile.readAsLinesSync();
  final outLines = <String>[];
  
  outLines.add('-- SCRIPT DE INSERCIÓN MASIVA DE EJERCICIOS');
  outLines.add('-- Ejecuta este archivo en el SQL Editor de Supabase (elimina los existentes antes si lo deseas)');
  outLines.add('');

  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('--')) {
      outLines.add(line);
      continue;
    }

    if (line.startsWith('UPDATE public.ejercicios SET')) {
      // Parse UPDATE statement
      // UPDATE public.ejercicios SET name = 'X', categoria = 'Y', description = 'Z' WHERE id = 'W';
      final nameMatch = RegExp(r"name = '(.*?)'").firstMatch(line);
      final catMatch = RegExp(r"categoria = '(.*?)'").firstMatch(line);
      final descMatch = RegExp(r"description = '(.*?)'").firstMatch(line);
      final idMatch = RegExp(r"id = '(.*?)'").firstMatch(line);

      if (nameMatch != null && catMatch != null && descMatch != null && idMatch != null) {
        final name = nameMatch.group(1)?.replaceAll("'", "''") ?? '';
        final cat = catMatch.group(1)?.replaceAll("'", "''") ?? '';
        final desc = descMatch.group(1)?.replaceAll("'", "''") ?? '';
        final id = idMatch.group(1) ?? '';

        outLines.add("INSERT INTO public.ejercicios (id, name, categoria, description) VALUES ('$id', '$name', '$cat', '$desc');");
      } else {
        outLines.add(line);
      }
    } else {
      outLines.add(line);
    }
  }

  outputFile.writeAsStringSync(outLines.join('\n'));
  print('Convertido exitosamente en insertar_ejercicios_espanol.sql');
}
