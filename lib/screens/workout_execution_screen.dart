import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import '../utils/exercise_gifs.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final Routine routine;

  const WorkoutExecutionScreen({
    super.key,
    required this.routine,
  });

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  
  // Elapsed time tracker
  late Timer _workoutTimer;
  int _secondsElapsed = 0;

  // Rest timer countdown tracker
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _showRestTimer = false;
  String _currentRestTimerLabel = 'Descanso';

  // Exercises and sets state
  List<Map<String, dynamic>> _workoutExercises = [];

  @override
  void initState() {
    super.initState();
    _initializeWorkoutData();
    _startWorkoutTimer();
  }

  @override
  void dispose() {
    _workoutTimer.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _initializeWorkoutData() {
    _workoutExercises = widget.routine.exercises.map((ex) {
      return {
        'exerciseId': ex.exerciseId,
        'name': ex.exerciseName,
        'description': ex.exerciseDescription,
        'imageUrl': ex.exerciseImageUrl,
        'notes': '',
        'sets': List.generate(ex.sets, (index) {
          final double weight = ex.seriesWeights.length > index ? ex.seriesWeights[index] : 0.0;
          return {
            'setNum': index + 1,
            'weight': weight,
            'reps': ex.reps,
            'completed': false,
            'previous': '${weight.toStringAsFixed(0)} kg x ${ex.reps}',
          };
        }),
      };
    }).toList();
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _startRestTimer(String exerciseName) {
    _restTimer?.cancel();
    setState(() {
      _currentRestTimerLabel = exerciseName;
      _restSecondsRemaining = 120; // 2 minutes default rest
      _showRestTimer = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _showRestTimer = false;
          _restSecondsRemaining = 0;
        });
        // Rest over SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Descanso terminado! Siguiente serie.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.black,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
      }
    });
  }

  void _adjustRestTimer(int deltaSeconds) {
    setState(() {
      _restSecondsRemaining = (_restSecondsRemaining + deltaSeconds).clamp(0, 999);
    });
  }

  void _skipRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _showRestTimer = false;
      _restSecondsRemaining = 0;
    });
  }

  // Calculate live volume (Weight * Reps) of completed sets
  double _calculateTotalVolume() {
    double volume = 0.0;
    for (var ex in _workoutExercises) {
      for (var set in ex['sets']) {
        if (set['completed'] == true) {
          volume += (set['weight'] as double) * (set['reps'] as int);
        }
      }
    }
    return volume;
  }

  // Count completed sets
  int _calculateCompletedSets() {
    int sets = 0;
    for (var ex in _workoutExercises) {
      for (var set in ex['sets']) {
        if (set['completed'] == true) {
          sets++;
        }
      }
    }
    return sets;
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  String _formatTimerString(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _addSetToExercise(int exerciseIndex) {
    setState(() {
      final setsList = _workoutExercises[exerciseIndex]['sets'] as List;
      final int newSetNum = setsList.length + 1;
      
      double defaultWeight = 0.0;
      int defaultReps = 10;
      if (setsList.isNotEmpty) {
        defaultWeight = setsList.last['weight'] as double;
        defaultReps = setsList.last['reps'] as int;
      }

      setsList.add({
        'setNum': newSetNum,
        'weight': defaultWeight,
        'reps': defaultReps,
        'completed': false,
        'previous': '${defaultWeight.toStringAsFixed(0)} kg x $defaultReps',
      });
    });
  }

  Future<void> _finishWorkout() async {
    final int completedSetsCount = _calculateCompletedSets();
    if (completedSetsCount == 0) {
      final confirmExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Rutina Vacía', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('No has completado ninguna serie de esta rutina aún. ¿Deseas salir del entrenamiento?', style: GoogleFonts.inter()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Seguir Entrenando', style: GoogleFonts.inter(color: Colors.black)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Salir', style: GoogleFonts.inter(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmExit == true) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    final double totalVolume = _calculateTotalVolume();
    final String timeStr = _formatDuration(_secondsElapsed);

    final finishConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '¿Terminar Entrenamiento?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_outlined, size: 48, color: Colors.black),
            const SizedBox(height: 16),
            Text(
              '¡Gran esfuerzo! Aquí está el resumen de tu rutina:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF525252), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Duración', timeStr),
                _buildSummaryStat('Volumen', '${totalVolume.toStringAsFixed(0)} kg'),
                _buildSummaryStat('Series', '$completedSetsCount'),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Seguir', style: GoogleFonts.inter(color: const Color(0xFF737373))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Terminar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (finishConfirm == true) {
      // Build logged exercises JSON
      final List<Map<String, dynamic>> loggedExs = _workoutExercises.map((ex) {
        final List<Map<String, dynamic>> setsData = (ex['sets'] as List).map((s) {
          return {
            'weight': s['weight'],
            'reps': s['reps'],
            'completed': s['completed'],
          };
        }).toList();
        
        return {
          'exercise_name': ex['name'],
          'sets': setsData,
          'notes': ex['notes'],
        };
      }).toList();

      final log = WorkoutLog(
        id: '',
        userId: _supabaseService.loggedInUserProfile?.userID ?? '',
        routineId: widget.routine.id,
        routineName: widget.routine.name,
        completedAt: DateTime.now(),
        durationSeconds: _secondsElapsed,
        totalVolume: totalVolume,
        totalSets: completedSetsCount,
        loggedExercises: loggedExs,
      );

      setState(() {
        _secondsElapsed = 0; // stop timer
      });

      final success = await _supabaseService.saveWorkoutLog(log);
      if (mounted) {
        if (success) {
          // Show gorgeous success overlay/alert
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      '¡Entrenamiento Guardado!',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu entrenamiento se registró correctamente. ¡Excelente trabajo hoy!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Listo', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar el entrenamiento en Supabase.')),
          );
        }
        Navigator.pop(context); // Exit execution screen
      }
    }
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double currentVolume = _calculateTotalVolume();
    final int completedSets = _calculateCompletedSets();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: Text('¿Abandonar Entrenamiento?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    content: Text('¿Seguro que deseas salir del entrenamiento activo? Se perderá el progreso de esta sesión.', style: GoogleFonts.inter()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Seguir entrenando', style: GoogleFonts.inter(color: Colors.black))),
                      TextButton(onPressed: () {
                        Navigator.pop(context); // close dialog
                        Navigator.pop(context); // exit execution screen
                      }, child: Text('Abandonar', style: GoogleFonts.inter(color: Colors.redAccent))),
                    ],
                  ),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 24),
                  SizedBox(width: 4),
                  Icon(Icons.timer_outlined, color: Colors.black, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.routine.name,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _finishWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(80, 34),
                elevation: 0,
              ),
              child: Text(
                'Terminar',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Statistics Row
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBox('DURACIÓN', _formatTimerString(_secondsElapsed)),
                    _buildStatBox('VOLUMEN', '${currentVolume.toStringAsFixed(0)} kg'),
                    _buildStatBox('SERIES', '$completedSets'),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFF5F5F5),
                      child: Icon(Icons.accessibility_new, color: Colors.black, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF5F5F5), height: 1),

              // Exercises List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: _showRestTimer ? 120 : 40,
                  ),
                  itemCount: _workoutExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = _workoutExercises[index];
                    return _buildExerciseCard(exercise, index);
                  },
                ),
              ),
            ],
          ),

          // Persistent Rest Timer Banner
          if (_showRestTimer)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Descanso: ${_currentRestTimerLabel}',
                            style: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimerString(_restSecondsRemaining),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _adjustRestTimer(-15),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF404040)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: Text('-15', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => _adjustRestTimer(15),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF404040)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: Text('+15', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _skipRestTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: Text('Omitir', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int exerciseIndex) {
    final setsList = exercise['sets'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: () {
                      final name = exercise['name']?.toString() ?? '';
                      final gifUrl = ExerciseGifs.getGifUrl(name);
                      final displayUrl = gifUrl ?? exercise['imageUrl']?.toString();
                      if (displayUrl != null && displayUrl.isNotEmpty) {
                        return Image.network(
                          displayUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.fitness_center,
                            color: Color(0xFF737373),
                            size: 20,
                          ),
                        );
                      }
                      return const Icon(
                        Icons.fitness_center,
                        color: Color(0xFF737373),
                        size: 20,
                      );
                    }(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise['name'],
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exercise['description'] ?? '',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF737373)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF737373)),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notes field
            TextField(
              onChanged: (val) => exercise['notes'] = val,
              style: GoogleFonts.inter(color: Colors.black, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Agregar notas aquí...',
                hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5E5))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 14),

            // Rest instruction
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFFA3A3A3), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Descanso: 2min 0s',
                  style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table of Series
            _buildSeriesTableHeader(),
            ...List.generate(setsList.length, (setIdx) {
              final setObj = setsList[setIdx];
              return _buildSeriesTableRow(setObj, exerciseIndex, setIdx, exercise['name']);
            }),

            const SizedBox(height: 12),

            // Add set button
            ElevatedButton.icon(
              onPressed: () => _addSetToExercise(exerciseIndex),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                'Agregar Serie',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              'SERIE',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFA3A3A3), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'ANTERIOR',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFA3A3A3), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'PESO (kg)',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFA3A3A3), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              'REPS',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFA3A3A3), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 36,
            child: Icon(Icons.check, size: 14, color: Color(0xFFA3A3A3)),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesTableRow(Map<String, dynamic> setObj, int exerciseIndex, int setIdx, String exerciseName) {
    final bool isCompleted = setObj['completed'] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 44,
            child: Text(
              '${setObj['setNum']}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isCompleted ? Colors.green.shade800 : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Previous info
          Expanded(
            flex: 2,
            child: Text(
              '${setObj['previous']}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isCompleted ? Colors.green.shade700 : const Color(0xFF737373),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Weight input
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: '${setObj['weight']}',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                enabled: !isCompleted,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green.shade800 : Colors.black,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isCompleted ? Colors.transparent : const Color(0xFFFAFAFA),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black)),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val) ?? 0.0;
                  setObj['weight'] = parsed;
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reps input
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 32,
              child: TextFormField(
                initialValue: '${setObj['reps']}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: !isCompleted,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green.shade800 : Colors.black,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isCompleted ? Colors.transparent : const Color(0xFFFAFAFA),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black)),
                  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val) ?? 0;
                  setObj['reps'] = parsed;
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Checkbox check button
          SizedBox(
            width: 36,
            height: 32,
            child: InkWell(
              onTap: () {
                setState(() {
                  setObj['completed'] = !isCompleted;
                  if (setObj['completed'] == true) {
                    _startRestTimer(exerciseName);
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isCompleted ? Colors.green : const Color(0xFFFAFAFA),
                  border: Border.all(
                    color: isCompleted ? Colors.green : const Color(0xFFE5E5E5),
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: isCompleted ? Colors.white : const Color(0xFFD4D4D4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
