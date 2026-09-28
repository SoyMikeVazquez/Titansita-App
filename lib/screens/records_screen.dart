import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/measurement_record.dart';
import 'add_record_screen.dart';

class RecordsScreen extends StatefulWidget {
  final String? userId;
  final String? clientName;

  const RecordsScreen({
    super.key,
    this.userId,
    this.clientName,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<MeasurementRecord> _records = [];
  String _activeMetric = 'Peso'; // Default metric to plot
  String? _error;

  // List of available metrics for the progress chart
  final List<Map<String, String>> _metricsList = [
    {'name': 'Peso', 'unit': 'Kg'},
    {'name': 'Abdomen', 'unit': 'cm'},
    {'name': 'Cintura', 'unit': 'cm'},
    {'name': 'Pierna', 'unit': 'cm'},
    {'name': 'Pecho', 'unit': 'cm'},
    {'name': 'Bicep', 'unit': 'cm'},
    {'name': 'Pantorrilla', 'unit': 'cm'},
    {'name': 'Cuello', 'unit': 'cm'},
  ];

  bool get _isAdminView => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recordsList = await _supabaseService.getMeasurementRecords(userId: widget.userId);
      if (mounted) {
        setState(() {
          _records = recordsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar registros: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Eliminar Registro',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este registro de medidas? Esta acción no se puede deshacer.',
          style: GoogleFonts.inter(color: const Color(0xFF525252)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: const Color(0xFF737373))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _supabaseService.deleteMeasurementRecord(id);
      if (success) {
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro eliminado correctamente', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar el registro'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.clientName != null ? 'Registros de ${widget.clientName}' : 'Registros';
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: GoogleFonts.inter(color: const Color(0xFF737373))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRecords,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                        child: Text('Reintentar', style: GoogleFonts.inter(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : _records.isEmpty
                  ? RefreshIndicator(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      onRefresh: _loadRecords,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.show_chart, size: 64, color: Color(0xFFD4D4D4)),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes registros de medidas aún.',
                                style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF737373)),
                              ),
                              const SizedBox(height: 24),
                              if (!_isAdminView)
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AddRecordScreen()),
                                    ).then((_) => _loadRecords());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Crear Primer Registro', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      onRefresh: _loadRecords,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            // Horizontal cards carousel
                            SizedBox(
                              height: 420,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _records.length,
                                itemBuilder: (context, index) {
                                  final record = _records[index];
                                  return _buildRecordCard(record);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Chart Section Title
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Progreso en ${_activeMetric.toLowerCase()}',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Metrics selection chips
                            SizedBox(
                              height: 38,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _metricsList.length,
                                itemBuilder: (context, index) {
                                  final metric = _metricsList[index]['name']!;
                                  final isSelected = _activeMetric == metric;
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        metric,
                                        style: GoogleFonts.inter(
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: Colors.black,
                                      backgroundColor: const Color(0xFFF5F5F5),
                                      disabledColor: Colors.transparent,
                                      side: BorderSide(
                                        color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => _activeMetric = metric);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Chart container
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildProgressChart(),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
      floatingActionButton: (!_isLoading && !_isAdminView)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddRecordScreen()),
                ).then((_) => _loadRecords());
              },
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildRecordCard(MeasurementRecord record) {
    final dateStr = DateFormat('d MMM, yyyy', 'es').format(record.createdAt);
    
    // Altura helper (get it from profile or show if we have height in user table, or prefill).
    // In this view, height is saved or shown if not empty.
    
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Photo
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            child: SizedBox(
              height: 120,
              child: record.photoUrl != null && record.photoUrl!.isNotEmpty
                  ? Image.network(
                      record.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.fitness_center, color: Color(0xFF737373), size: 36),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_not_supported_outlined, color: Color(0xFFA3A3A3), size: 30),
                          const SizedBox(height: 4),
                          Text(
                            'Sin foto de progreso',
                            style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          
          // Measurement list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecordItem('Peso', '${record.weight.toStringAsFixed(1)} Kg'),
                  _buildRecordItem('Medida de cuello', '${record.cuello.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de pecho', '${record.chest.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de bicep', '${record.arm.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de abdomen', '${record.abdomen.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de cintura', '${record.waist.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de pierna', '${record.leg.toStringAsFixed(0)} cm'),
                  _buildRecordItem('Medida de pantorrilla', '${record.calf.toStringAsFixed(0)} cm'),
                  const Divider(color: Color(0xFFF5F5F5), height: 16),
                  _buildRecordItem('Fecha', dateStr, isBoldValue: true),
                ],
              ),
            ),
          ),

          // Delete button (hide for admin)
          if (!_isAdminView)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
              child: TextButton(
                onPressed: () => _deleteRecord(record.id),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 32),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'Eliminar registro',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(String label, String value, {bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(color: const Color(0xFF171717), fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF737373)),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart() {
    if (_records.length < 2) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Registra al menos 2 medidas para visualizar tu gráfica de progreso.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF737373),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    // Prepare chart data spots (order: chronological from oldest to newest)
    final sortedRecords = List<MeasurementRecord>.from(_records)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    List<FlSpot> spots = [];
    double minY = double.maxFinite;
    double maxY = double.minPositive;

    for (int i = 0; i < sortedRecords.length; i++) {
      final val = sortedRecords[i].getValueByName(_activeMetric);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    // Add padding to Y range for visual neatness
    final rangeY = maxY - minY;
    if (rangeY == 0) {
      minY = minY - 5;
      maxY = maxY + 5;
    } else {
      minY = (minY - (rangeY * 0.15)).clamp(0, double.maxFinite);
      maxY = maxY + (rangeY * 0.15);
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 20, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF5F5F5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toStringAsFixed(1),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF737373),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < sortedRecords.length) {
                          // Only show titles on some ticks to avoid overlapping
                          final showTick = sortedRecords.length <= 5 || 
                              idx == 0 || 
                              idx == sortedRecords.length - 1 || 
                              idx == (sortedRecords.length / 2).floor();
                          
                          if (showTick) {
                            final date = sortedRecords[idx].createdAt;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('d MMM', 'es').format(date),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF737373),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: (sortedRecords.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: Colors.black,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: true,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.00),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedBarSpot) => Colors.black,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = sortedRecords[spot.x.toInt()].createdAt;
                        final formattedDate = DateFormat('d MMM, yyyy', 'es').format(date);
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} ${_metricsList.firstWhere((m) => m['name'] == _activeMetric)['unit']}\n$formattedDate',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Y: $_activeMetric  •  X: Tiempo',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
