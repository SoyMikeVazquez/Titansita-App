import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/trainer.dart';
import '../models/user_profile.dart';

class SuperAdminFinancesScreen extends StatefulWidget {
  const SuperAdminFinancesScreen({super.key});

  @override
  State<SuperAdminFinancesScreen> createState() => _SuperAdminFinancesScreenState();
}

class _SuperAdminFinancesScreenState extends State<SuperAdminFinancesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _error;

  List<Trainer> _trainers = [];
  List<Map<String, dynamic>> _allPayments = [];
  Map<String, int> _trainerClientsCount = {}; // Map of trainerId -> active clients count

  List<double> _revenueData = [0.0];
  List<String> _months = ['Ene'];
  double _totalRecaudadoPlataforma = 0.0;
  double _totalRecaudadoEntrenadores = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Cargar entrenadores activos e inactivos
      final activeTrainers = await _supabaseService.getTrainers();
      final inactiveTrainers = await _supabaseService.getInactiveTrainers();
      final trainersList = [...activeTrainers, ...inactiveTrainers];

      // 2. Cargar todos los pagos registrados
      final paymentsList = await _supabaseService.getAllPayments();

      // 3. Cargar la cantidad real de clientes por entrenador
      final Map<String, int> clientsCountMap = {};
      final client = _supabaseService.client;
      for (final t in trainersList) {
        try {
          final response = await client
              .from('users')
              .select('userID')
              .eq('is_admin', false)
              .eq('IDEmpresa', t.id);
          clientsCountMap[t.id] = (response as List).length;
        } catch (_) {
          clientsCountMap[t.id] = 0;
        }
      }

      // 4. Calcular métricas reales y preparar gráfica de los últimos 3 meses
      final platformPayments = paymentsList.where((p) => p['tipo'] == 'entrenador_a_plataforma').toList();
      final trainerPayments = paymentsList.where((p) => p['tipo'] == 'cliente_a_entrenador').toList();

      final double realPlataforma = platformPayments.fold(0.0, (sum, p) => sum + (p['monto'] as num).toDouble());
      final double realEntrenadores = trainerPayments.fold(0.0, (sum, p) => sum + (p['monto'] as num).toDouble());

      final Map<String, double> monthlySums = {};
      final List<String> rangeKeys = [];
      final now = DateTime.now();
      
      final monthNamesShort = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      for (int i = 2; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        rangeKeys.add(key);
        monthlySums[key] = 0.0;
      }

      for (final p in platformPayments) {
        final fechaStr = p['fecha'] as String?;
        if (fechaStr != null) {
          final fecha = DateTime.parse(fechaStr);
          final key = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}";
          if (monthlySums.containsKey(key)) {
            monthlySums[key] = monthlySums[key]! + (p['monto'] as num).toDouble();
          }
        }
      }

      List<double> finalRevenue = [];
      List<String> finalMonths = [];

      for (final key in rangeKeys) {
        final parts = key.split('-');
        final monthIdx = int.parse(parts[1]) - 1;
        finalMonths.add(monthNamesShort[monthIdx]);
        finalRevenue.add(monthlySums[key]!);
      }

      if (mounted) {
        setState(() {
          _trainers = trainersList;
          _allPayments = paymentsList;
          _trainerClientsCount = clientsCountMap;
          _revenueData = finalRevenue;
          _months = finalMonths;
          _totalRecaudadoPlataforma = realPlataforma;
          _totalRecaudadoEntrenadores = realEntrenadores;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando finanzas de Super Admin: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerTrainerPayment(Trainer trainer) async {
    final monto = trainer.montodecobroMensual;
    final now = DateTime.now();

    // Mostrar diálogo de confirmación
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Registrar Pago de Entrenador',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas registrar un pago de \$${monto.toStringAsFixed(2)} MXN para el entrenador ${trainer.nombre}? Esto extenderá su acceso por su ciclo de facturación.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: Text('Registrar', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    // Calcular próxima fecha de cobro según modalidad
    DateTime proximoPago = trainer.proximoPago ?? now;
    final modalidad = trainer.modalidadPago ?? 'mensual';
    if (modalidad == 'mensual') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 1, proximoPago.day);
    } else if (modalidad == 'bimestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 2, proximoPago.day);
    } else if (modalidad == 'trimestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 3, proximoPago.day);
    } else if (modalidad == 'semestral') {
      proximoPago = DateTime(proximoPago.year, proximoPago.month + 6, proximoPago.day);
    } else if (modalidad == 'anual') {
      proximoPago = DateTime(proximoPago.year + 1, proximoPago.month, proximoPago.day);
    }

    // 1. Guardar el registro del pago
    final successLog = await _supabaseService.registerPayment(
      idEmpresa: trainer.id,
      monto: monto,
      tipo: 'entrenador_a_plataforma',
      concepto: 'Mensualidad plataforma entrenador (${modalidad.toUpperCase()})',
    );

    // 2. Actualizar las fechas de cobro en EmpresasEntrenadores
    final successUpdate = await _supabaseService.updateTrainer(
      trainerId: trainer.id,
      fechaPago: now,
      proximoPago: proximoPago,
    );

    if (mounted) {
      if (successLog && successUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pago registrado con éxito para ${trainer.nombre} ✅',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadData();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar el pago de mensualidad del entrenador'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return "${date.day} ${months[date.month - 1]}, ${date.year}";
  }

  int _getDaysDifference(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paymentDate = DateTime(date.year, date.month, date.day);
    return paymentDate.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    // Calcular límites dinámicos para la gráfica de ingresos
    final double maxVal = _revenueData.isNotEmpty ? _revenueData.reduce(max) : 0.0;
    final double minVal = _revenueData.isNotEmpty ? _revenueData.reduce(min) : 0.0;
    final double minY = (minVal - 500).clamp(0.0, double.infinity);
    double maxY = maxVal + 1000;
    if (maxY <= minY) {
      maxY = minY + 3000;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Finanzas Generales',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? Center(
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
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: Text('Reintentar', style: GoogleFonts.inter(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Metric summaries
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Recaudado por mis servicios',
                                value: '\$${_totalRecaudadoPlataforma.toStringAsFixed(0)}',
                                subtitle: 'Cobros a entrenadores',
                                color: Colors.black,
                                bgColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Generado Entrenadores',
                                value: '\$${_totalRecaudadoEntrenadores.toStringAsFixed(0)}',
                                subtitle: 'Cobros a clientes',
                                color: const Color(0xFF22C55E),
                                bgColor: const Color(0xFFF0FDF4),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Line Chart (Curved, thin line, dots)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingresos Mensuales Plataforma',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'Facturación acumulada cobrada a entrenadores',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF737373),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 180,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 42,
                                          getTitlesWidget: (value, meta) {
                                            if (value >= 1000) {
                                              return Text(
                                                '\$${(value / 1000).toStringAsFixed(1)}k',
                                                style: GoogleFonts.inter(
                                                  color: const Color(0xFFA3A3A3),
                                                  fontSize: 9,
                                                ),
                                              );
                                            }
                                            return Text(
                                              '\$${value.toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFA3A3A3),
                                                fontSize: 9,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 && index < _months.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  _months[index],
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF737373),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    minX: 0,
                                    maxX: (_revenueData.length - 1).toDouble(),
                                    minY: minY,
                                    maxY: maxY,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: List.generate(_revenueData.length, (index) {
                                          return FlSpot(index.toDouble(), _revenueData[index]);
                                        }),
                                        isCurved: true,
                                        barWidth: 2.0, // Fine line
                                        color: Colors.black,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: Colors.black,
                                              strokeWidth: 1.5,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.08),
                                              Colors.black.withOpacity(0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Trainer list header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                        child: Text(
                          'Facturación de Entrenadores',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // 4. Trainer List
                      if (_trainers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay entrenadores registrados',
                                  style: GoogleFonts.inter(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          itemCount: _trainers.length,
                          itemBuilder: (context, index) {
                            final trainer = _trainers[index];
                            final clientsCount = _trainerClientsCount[trainer.id] ?? 0;
                            final monthlySales = clientsCount * 499.0;
                            final isPending = trainer.proximoPago != null && trainer.proximoPago!.isBefore(DateTime.now());
                            final diffDays = _getDaysDifference(trainer.proximoPago);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E5E5)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Trainer Photo
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(0xFFF5F5F5),
                                        backgroundImage: trainer.fotoPerfil != null && trainer.fotoPerfil!.isNotEmpty
                                            ? NetworkImage(trainer.fotoPerfil!)
                                            : null,
                                        child: trainer.fotoPerfil == null || trainer.fotoPerfil!.isEmpty
                                            ? const Icon(Icons.person, color: Color(0xFF737373), size: 22)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trainer.nombre,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                            Text(
                                              '${clientsCount} clientes activos • \$${monthlySales.toStringAsFixed(0)} MXN/mes',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF737373),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPending ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isPending
                                              ? (diffDays < 0 ? 'Atrasado (${-diffDays}d)' : 'Vence hoy')
                                              : 'Al corriente',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isPending ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Color(0xFFF5F5F5), height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Cobro Mensual de Servicios en Efectivo',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: const Color(0xFF737373),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '\$${trainer.montodecobroMensual.toStringAsFixed(2)} MXN',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Corte: ${_formatDate(trainer.proximoPago)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: const Color(0xFFA3A3A3),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _registerTrainerPayment(trainer),
                                        icon: const Icon(Icons.check_circle_outline, size: 14),
                                        label: Text(
                                          'Registrar Pago',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color == Colors.black ? const Color(0xFFE5E5E5) : color.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color == Colors.black ? const Color(0xFF737373) : color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }
}
