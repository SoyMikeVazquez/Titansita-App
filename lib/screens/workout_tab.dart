import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/routine.dart';
import '../models/workout_log.dart';
import 'workout_execution_screen.dart';

class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Routine> _routines = [];
  List<WorkoutLog> _workoutLogs = [];
  String _searchQuery = '';
  bool _isFolderExpanded = true;
  String? _error;
  
  late DateTime _selectedDate;
  late List<DateTime> _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _generateDateRange();
    _loadRoutines();
  }

  void _generateDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dateRange = List.generate(14, (index) {
      return today.subtract(Duration(days: 7 - index));
    });
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final currentUserId = _supabaseService.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final assignedList = await _supabaseService.getAssignedRoutines(userId: currentUserId);
        final list = assignedList.map((ar) {
          return Routine(
            id: ar.id,
            userId: ar.userId,
            name: ar.routineName,
            assignedDate: ar.assignedDate,
            createdAt: ar.createdAt,
            exercises: ar.customExercises,
          );
        }).toList();

        final logs = await _supabaseService.getWorkoutLogs(userId: currentUserId);

        if (mounted) {
          setState(() {
            _routines = list;
            _workoutLogs = logs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _routines = [];
            _workoutLogs = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar rutinas: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter routine(s) of the selected calendar date
    final routineOfTheDay = _routines.where((r) {
      if (r.assignedDate == null) return false;
      final assignD = DateTime(r.assignedDate!.year, r.assignedDate!.month, r.assignedDate!.day);
      return assignD.isAtSameMomentAs(_selectedDate);
    }).toList();



    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: _loadRoutines,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Title and Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'Entrenamiento',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF171717),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
                    ],
                  ),
                ),
              ),

              // 2. Calendar Selector
              SliverToBoxAdapter(
                child: _buildHorizontalCalendar(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 4. Routines content
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.black)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF737373))),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadRoutines,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                            child: Text('Reintentar', style: GoogleFonts.inter(color: Colors.white)),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              else if (_routines.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fitness_center_outlined, size: 48, color: Color(0xFFD4D4D4)),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes rutinas asignadas aún.',
                          style: GoogleFonts.inter(color: const Color(0xFF737373)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    // 4.1 Rutina del Día Section Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Rutina del Día',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4.2 Rutina del Día Content (The scheduled routine card or rest day card)
                    _buildRoutineOfTheDaySection(routineOfTheDay),
                    const SizedBox(height: 100),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final selectedMonthYear = "${months[_selectedDate.month - 1]} ${_selectedDate.year}";

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedMonthYear,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Desliza para ver más días',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _dateRange.length,
              itemBuilder: (context, index) {
                final date = _dateRange[index];
                final isSelected = date.isAtSameMomentAs(_selectedDate);
                final dayOfWeek = _getDayOfWeekAbbr(date.weekday);
                final isToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
                    .isAtSameMomentAs(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.black 
                            : isToday 
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFFE5E5E5),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayOfWeek,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getDayOfWeekAbbr(int weekday) {
    switch (weekday) {
      case 1: return 'Lun';
      case 2: return 'Mar';
      case 3: return 'Mié';
      case 4: return 'Jue';
      case 5: return 'Vie';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }

  Widget _buildRoutineOfTheDaySection(List<Routine> routineList) {
    if (routineList.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.nightlight_round_outlined, color: Color(0xFFF97316), size: 40),
            const SizedBox(height: 12),
            Text(
              'Día de Descanso',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay rutinas programadas para este día. ¡Recupera energía!',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF737373),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Limit to maximum of 2 daily routines
    final dailyRoutines = routineList.take(2).toList();

    return Column(
      children: dailyRoutines.asMap().entries.map((entry) {
        final index = entry.key;
        final routine = entry.value;
        return _buildRoutineCard(
          routine,
          isDailyRoutine: true,
          isPrincipal: index == 0,
        );
      }).toList(),
    );
  }

  Widget _buildRoutineCard(Routine routine, {bool isDailyRoutine = false, bool isPrincipal = true}) {
    // Extract exercise names for subtitle
    final exerciseNames = routine.exercises.map((e) => e.exerciseName).join(', ');
    final subText = exerciseNames.isNotEmpty ? exerciseNames : 'Sin ejercicios agregados aún';

    // Find matching workout log
    WorkoutLog? matchingLog;
    for (var log in _workoutLogs) {
      if (log.routineId == routine.id) {
        matchingLog = log;
        break;
      }
    }

    return GestureDetector(
      onTap: () => _showRoutineDetailBottomSheet(routine),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDailyRoutine) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPrincipal ? Colors.black : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                        border: isPrincipal ? null : Border.all(color: const Color(0xFFD4D4D4)),
                      ),
                      child: Text(
                        isPrincipal ? 'Rutina Principal' : 'Rutina Opcional',
                        style: GoogleFonts.inter(
                          color: isPrincipal ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (matchingLog != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'REALIZADA ✅',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF15803D),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      routine.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF171717),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Color(0xFF737373)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'details') {
                        _showRoutineDetailBottomSheet(routine);
                      } else if (val == 'share') {
                        final shareCode = routine.shareCode ?? '';
                        Clipboard.setData(ClipboardData(text: 'https://personaltrainer.mx/routine?code=$shareCode'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡Enlace de rutina copiado! Código: $shareCode', style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.black,
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            const Icon(Icons.fitness_center_outlined, color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            Text('Ver Ejercicios', style: GoogleFonts.inter(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            const Icon(Icons.share_outlined, color: Colors.black, size: 18),
                            const SizedBox(width: 8),
                            Text('Compartir Rutina', style: GoogleFonts.inter(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subText,
                style: GoogleFonts.inter(
                  color: const Color(0xFF737373),
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (matchingLog != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('TIEMPO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text('${(matchingLog.durationSeconds / 60).floor()}m ${matchingLog.durationSeconds % 60}s', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('VOLUMEN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text('${matchingLog.totalVolume.toStringAsFixed(0)} kg', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('SERIES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text('${matchingLog.totalSets}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (matchingLog != null) {
                    _showWorkoutSummaryBottomSheet(matchingLog, routine);
                    return;
                  }
                  if (routine.exercises.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Esta rutina no tiene ejercicios asignados por el entrenador.', style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.black,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutExecutionScreen(routine: routine),
                    ),
                  ).then((_) => _loadRoutines());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  matchingLog != null ? 'Ver Resumen' : 'Empezar Rutina',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoutineDetailBottomSheet(Routine routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_outlined, color: Colors.black, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.exercises.isEmpty
                                  ? 'Sin ejercicios'
                                  : '${routine.exercises.length} ${routine.exercises.length == 1 ? "ejercicio" : "ejercicios"}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF737373),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              routine.name,
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFF5F5F5), height: 1),
                
                Expanded(
                  child: routine.exercises.isEmpty
                      ? Center(
                          child: Text(
                            'Esta rutina no tiene ejercicios agregados.',
                            style: GoogleFonts.inter(color: const Color(0xFF737373)),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: routine.exercises.length,
                          itemBuilder: (context, index) {
                            final ex = routine.exercises[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E5E5)),
                              ),
                              child: Row(
                                children: [
                                  if (ex.exerciseImageUrl != null && ex.exerciseImageUrl!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        ex.exerciseImageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.fitness_center, color: Color(0xFF9CA3AF)),
                                    ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ex.exerciseName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                        if (ex.exerciseDescription.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            ex.exerciseDescription,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF737373),
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${ex.sets}x${ex.reps}',
                                                style: GoogleFonts.inter(
                                                  color: Colors.black,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Tipo: ${ex.seriesType}',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF737373),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (routine.exercises.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Esta rutina no tiene ejercicios asignados por el entrenador.', style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.black,
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutExecutionScreen(routine: routine),
                            ),
                          ).then((_) => _loadRoutines());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Empezar Rutina',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWorkoutSummaryBottomSheet(WorkoutLog log, Routine routine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen de Entrenamiento',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF737373),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              log.routineName,
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFF5F5F5), height: 1),
                
                // Stats Box
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('TIEMPO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                          const SizedBox(height: 2),
                          Text('${(log.durationSeconds / 60).floor()}m ${log.durationSeconds % 60}s', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('VOLUMEN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                          const SizedBox(height: 2),
                          Text('${log.totalVolume.toStringAsFixed(0)} kg', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                        ],
                      ),
                      Column(
                        children: [
                          Text('SERIES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                          const SizedBox(height: 2),
                          Text('${log.totalSets}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: log.loggedExercises.isEmpty
                      ? Center(
                          child: Text(
                            'No se registraron ejercicios.',
                            style: GoogleFonts.inter(color: const Color(0xFF737373)),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                          itemCount: log.loggedExercises.length,
                          itemBuilder: (context, index) {
                            final ex = log.loggedExercises[index];
                            final setsList = ex['sets'] as List? ?? [];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E5E5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex['exercise_name'] ?? 'Ejercicio',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...setsList.asMap().entries.map((entry) {
                                    final setIdx = entry.key;
                                    final setData = entry.value;
                                    final isCompleted = setData['completed'] == true;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCompleted ? Icons.check_circle : Icons.cancel,
                                            size: 16,
                                            color: isCompleted ? Colors.green : Colors.redAccent,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Serie ${setIdx + 1}: ${setData['weight']} kg x ${setData['reps']} reps',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  if (ex['notes'] != null && ex['notes'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Mi nota: "${ex['notes']}"',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
