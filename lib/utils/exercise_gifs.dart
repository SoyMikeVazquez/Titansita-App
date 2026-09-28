class ExerciseGifs {
  static const Map<String, String> _gifMap = {
    'sentadilla libre con barra':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif',
    'sentadilla completa con barra':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif',
    'sentadilla':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/barbell-full-squat.gif',
    'prensa de piernas inclinada':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/sled-45-leg-press.gif',
    'prensa de piernas':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/sled-45-leg-press.gif',
    'zancadas búlgaras con mancuerna':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/dumbbell-single-leg-split-squat.gif',
    'zancadas búlgaras':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/dumbbell-single-leg-split-squat.gif',
    'extensión de cuádriceps en máquina':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif',
    'extensión de cuádriceps':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif',
    'extensión de pierna':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/quads/lever-leg-extension.gif',
    'peso muerto rumano':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/hamstrings/barbell-romanian-deadlift.gif',
    'press de banca plano':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/chest/barbell-bench-press.gif',
    'fondos en paralelas':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/triceps/bodyweight-chest-dip.gif',
    'plancha abdominal':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/abs/plank.gif',
    'caminadora':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/cardio/walking-on-incline-treadmill.gif',
    'calentamiento general':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/cardio/walking-on-incline-treadmill.gif',
    'abducción de caderas':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/glutes/seated-hip-abduction.gif',
    'abdominal corto':
        'https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@main/abs/crunch.gif',
  };

  static const Map<String, List<String>> _instructionsMap = {
    'sentadilla libre con barra': [
      'Coloca la barra a la altura del pecho en el rack y sitúate debajo apoyándola sobre los trapecios.',
      'Saca la barra del rack, da un paso atrás y separa los pies al ancho de hombros con las puntas apuntando ligeramente hacia afuera.',
      'Inicia el descenso flexionando caderas y rodillas simultáneamente, manteniendo el torso erguido y las rodillas alineadas con las puntas de los pies.',
      'Baja hasta que tus caderas superen la línea de las rodillas (rompiendo el paralelo).',
      'Sube empujando el suelo con toda la planta del pie hasta volver a la posición inicial extendiendo rodillas y caderas.',
    ],
    'prensa de piernas inclinada': [
      'Siéntate en la máquina de prensa y apoya la espalda firmemente en el respaldo.',
      'Coloca los pies en la plataforma separados al ancho de hombros.',
      'Empuja la plataforma para liberar los pestillos de seguridad, manteniendo las rodillas con una leve flexión (no las bloquees).',
      'Baja el peso controladamente flexionando las rodillas hacia tu pecho hasta formar un ángulo de 90 grados.',
      'Empuja la plataforma con fuerza hacia arriba extendiendo las piernas sin llegar a bloquear las rodillas.',
    ],
    'zancadas búlgaras con mancuerna': [
      'Sostén una mancuerna en cada mano y colócate de espaldas a un banco a una distancia de un paso largo.',
      'Apoya el empeine de un pie sobre el banco detrás de ti.',
      'Mantén el torso ligeramente inclinado hacia adelante y desciende la cadera de forma vertical controlando el movimiento.',
      'La rodilla delantera debe quedar alineada sobre el tobillo, y la rodilla trasera desciende casi hasta rozar el suelo.',
      'Sube empujando principalmente con el talón del pie delantero hasta volver a la posición inicial.',
    ],
    'extensión de cuádriceps en máquina': [
      'Ajusta la máquina de modo que el rodillo quede apoyado en la parte baja de la tibia, justo arriba de los tobillos, y tus rodillas coincidan con el eje de rotación de la máquina.',
      'Siéntate con la espalda bien apoyada en el respaldo y sujeta los agarres laterales.',
      'Realiza una extensión completa de rodillas contrayendo los cuádriceps con fuerza.',
      'Mantén la contracción durante 1 o 2 segundos en la posición de máxima extensión.',
      'Desciende el peso controladamente hasta la posición inicial sin dejar que las placas de peso se golpeen.',
    ],
    'peso muerto rumano': [
      'Sujeta la barra con las palmas hacia abajo al ancho de hombros y ponte de pie con los pies al ancho de caderas.',
      'Inicia el movimiento empujando la cadera hacia atrás (bisagra de cadera), manteniendo una flexión muy leve en las rodillas.',
      'Desciende la barra rozando los muslos y las espinacas hasta sentir un estiramiento marcado en los femorales y glúteos.',
      'Mantén la espalda completamente recta en todo momento, evitando redondearla.',
      'Vuelve a la posición inicial empujando la cadera hacia adelante y contrayendo los glúteos al subir.',
    ],
  };

  static String? getGifUrl(String name) {
    final cleanName = name
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true),
          '',
        )
        .trim();

    if (_gifMap.containsKey(cleanName)) {
      return _gifMap[cleanName];
    }

    for (final entry in _gifMap.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }
    return null;
  }

  static List<String> getInstructions(String name) {
    final cleanName = name
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true),
          '',
        )
        .trim();

    if (_instructionsMap.containsKey(cleanName)) {
      return _instructionsMap[cleanName]!;
    }

    for (final entry in _instructionsMap.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }

    return [
      'Adopta la postura inicial correcta y mantén una buena alineación corporal.',
      'Ejecuta el ejercicio de manera controlada prestando atención a la contracción del músculo objetivo.',
      'Realiza el movimiento completo controlando tanto la fase concéntrica como la excéntrica.',
      'Mantén la respiración: exhala durante el esfuerzo e inhala al regresar a la posición inicial.',
    ];
  }
}
