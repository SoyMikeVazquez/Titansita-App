import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../models/client_subscription.dart';
import '../models/payment_config.dart';
import 'client_finances_screen.dart';

class AdminFinancesScreen extends StatefulWidget {
  const AdminFinancesScreen({super.key});

  @override
  State<AdminFinancesScreen> createState() => _AdminFinancesScreenState();
}

class _AdminFinancesScreenState extends State<AdminFinancesScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _error;
  List<UserProfile> _clients = [];
  Map<String, ClientSubscription> _subscriptionsMap = {};
  PaymentConfig? _paymentConfig;
  String? _idEmpresa;
  
  List<double> _revenueData = [0.0];
  List<String> _months = ['Ene'];
  List<Map<String, dynamic>> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_clients.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final clientsList = await _supabaseService.getAllClients().timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
      
      // Obtener el perfil del entrenador para sacar su IDEmpresa
      final trainerProfile = await _supabaseService.getTrainerProfile().timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
      final idEmpresa = trainerProfile?.id ?? 'GENERAL';
      _idEmpresa = idEmpresa;
      
      // Obtener configuración de pagos por empresa
      final paymentConfig = await _supabaseService.getPaymentConfigByEmpresa(idEmpresa).timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );

      // Obtener suscripciones existentes
      final rawSubs = await _supabaseService.getClientSubscriptionsByEmpresa(idEmpresa).timeout(
        const Duration(seconds: 6),
        onTimeout: () => [],
      );
      final Map<String, ClientSubscription> subsMap = {};
      for (final sub in rawSubs) {
        subsMap[sub.clienteId] = sub;
      }

      // Asegurar que cada cliente tenga un objeto ClientSubscription local si aún no existe en DB
      for (final client in clientsList) {
        if (!subsMap.containsKey(client.userID)) {
          subsMap[client.userID] = ClientSubscription(
            id: '',
            clienteId: client.userID,
            idEmpresa: idEmpresa,
            montoMensualidad: paymentConfig?.montoDefault ?? 499.0,
            proximaFechaPago: client.nextPaymentDate ?? DateTime.now().add(const Duration(days: 30)),
            estatus: 'al_corriente',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
      
      List<Map<String, dynamic>> payments = [];
      if (idEmpresa != 'GENERAL') {
        payments = await _supabaseService.getPaymentsByEmpresa(idEmpresa).timeout(
          const Duration(seconds: 6),
          onTimeout: () => [],
        );
      }

      // Filtrar solo pagos de cliente a entrenador
      final clientPayments = payments.where((p) => p['tipo'] == 'cliente_a_entrenador').toList();

      // Procesar valores de facturación diarios (últimos 60 días)
      final rangeKeys = <String>[];
      final dailySums = <String, double>{};
      final now = DateTime.now();
      
      for (int i = 59; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        rangeKeys.add(key);
        dailySums[key] = 0.0;
      }

      for (final p in clientPayments) {
        final fechaStr = p['fecha'] as String?;
        if (fechaStr != null) {
          final fecha = DateTime.parse(fechaStr);
          final key = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
          if (dailySums.containsKey(key)) {
            dailySums[key] = dailySums[key]! + (p['monto'] as num).toDouble();
          }
        }
      }

      List<double> finalRevenue = [];
      List<String> finalDays = [];
      final monthNamesShort = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

      for (final key in rangeKeys) {
        final parts = key.split('-');
        final monthIdx = int.parse(parts[1]) - 1;
        final day = int.parse(parts[2]).toString();
        finalDays.add("$day ${monthNamesShort[monthIdx]}");
        finalRevenue.add(dailySums[key]!);
      }

      if (mounted) {
        setState(() {
          _clients = clientsList;
          _subscriptionsMap = subsMap;
          _paymentConfig = paymentConfig;
          _revenueData = finalRevenue;
          _months = finalDays;
          _recentPayments = clientPayments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando datos de finanzas: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _quickExtendPayment(UserProfile client) async {
    final sub = _subscriptionsMap[client.userID];
    final monto = sub?.montoMensualidad ?? 499.0;
    
    setState(() => _isLoading = true);

    final success = await _supabaseService.processManualPayment(
      clienteId: client.userID,
      idEmpresa: _idEmpresa ?? 'GENERAL',
      monto: monto,
      concepto: 'Pago mensualidad (Manual)',
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pago de \$${monto.toStringAsFixed(0)} registrado para ${client.name} ✅',
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
            content: Text('Error al procesar el pago'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showManualPaymentModal(UserProfile? initialClient) {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes registrados en esta empresa.')),
      );
      return;
    }

    UserProfile selectedClient = initialClient ?? _clients.first;
    final sub = _subscriptionsMap[selectedClient.userID];
    final montoCtrl = TextEditingController(
      text: (sub?.montoMensualidad ?? _paymentConfig?.montoDefault ?? 499.0).toStringAsFixed(0),
    );
    final notasCtrl = TextEditingController();
    
    String metodoPago = 'Efectivo';
    String estatusSeleccionado = 'al_corriente'; // 'al_corriente' o 'pendiente'
    DateTime fechaCorte = sub?.proximaFechaPago ?? DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Registrar Pago / Estatus Manual',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector de cliente
                    Text('Cliente', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF525252))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<UserProfile>(
                      value: selectedClient,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _clients.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedClient = val;
                            final s = _subscriptionsMap[val.userID];
                            montoCtrl.text = (s?.montoMensualidad ?? _paymentConfig?.montoDefault ?? 499.0).toStringAsFixed(0);
                            fechaCorte = s?.proximaFechaPago ?? DateTime.now().add(const Duration(days: 30));
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Estatus del pago
                    Text('Estatus del Pago', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF525252))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text('Al Corriente', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            selected: estatusSeleccionado == 'al_corriente',
                            selectedColor: const Color(0xFFDCFCE7),
                            backgroundColor: const Color(0xFFF5F5F5),
                            onSelected: (sel) {
                              if (sel) setModalState(() => estatusSeleccionado = 'al_corriente');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pending_actions, size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text('Pendiente', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            selected: estatusSeleccionado == 'pendiente',
                            selectedColor: const Color(0xFFFEE2E2),
                            backgroundColor: const Color(0xFFF5F5F5),
                            onSelected: (sel) {
                              if (sel) setModalState(() => estatusSeleccionado = 'pendiente');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Método de pago
                    if (estatusSeleccionado == 'al_corriente') ...[
                      Text('Forma de Pago Realizado', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF525252))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          'Efectivo',
                          'Transferencia SPEI',
                          'Tarjeta / Terminal',
                          'OXXO / Depósito',
                        ].map((met) {
                          final isSel = metodoPago == met;
                          return ChoiceChip(
                            label: Text(met, style: GoogleFonts.inter(fontSize: 11, color: isSel ? Colors.white : Colors.black)),
                            selected: isSel,
                            selectedColor: Colors.black,
                            backgroundColor: const Color(0xFFF5F5F5),
                            onSelected: (s) {
                              if (s) setModalState(() => metodoPago = met);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Monto
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto de Mensualidad (MXN)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector de fecha de corte
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Próxima Fecha de Corte', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF525252))),
                            const SizedBox(height: 2),
                            Text(
                              '${fechaCorte.day}/${fechaCorte.month}/${fechaCorte.year}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18, color: Colors.black),
                          label: Text('Cambiar', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fechaCorte,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setModalState(() => fechaCorte = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notas / Referencia
                    TextField(
                      controller: notasCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notas / Folio comprobante (Opcional)',
                        hintText: 'Ej. Folio 984122 / Pagado en gimnasio',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final monto = double.tryParse(montoCtrl.text.trim()) ?? 499.0;
                          final concepto = estatusSeleccionado == 'al_corriente'
                              ? 'Mensualidad ($metodoPago)'
                              : 'Pago pendiente marcado manualmente';
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(
                               content: Text('Guardando pago...'),
                               duration: Duration(seconds: 1),
                             ),
                           );

                          final success = await _supabaseService.processManualPayment(
                            clienteId: selectedClient.userID,
                            idEmpresa: _idEmpresa ?? 'GENERAL',
                            monto: monto,
                            concepto: concepto,
                            estatus: estatusSeleccionado,
                            customNextDate: fechaCorte,
                          ).timeout(
                            const Duration(seconds: 10),
                            onTimeout: () => false,
                          );

                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('¡Pago registrado con éxito para ${selectedClient.name}! ✅'),
                                  backgroundColor: Colors.black,
                                ),
                              );
                              await _loadData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ocurrió un error al registrar el pago. Revisa tu conexión o intenta de nuevo.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Guardar Registro de Pago',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentConfigModal() {
    final montoDefaultCtrl = TextEditingController(text: (_paymentConfig?.montoDefault ?? 499.0).toStringAsFixed(0));
    final publicKeyCtrl = TextEditingController(text: _paymentConfig?.publicKey ?? '');
    final secretKeyCtrl = TextEditingController(text: _paymentConfig?.secretKeyEncrypted ?? '');
    final instTransferCtrl = TextEditingController(text: _paymentConfig?.instruccionesTransferencia ?? '');
    String pasarelaSeleccionada = _paymentConfig?.pasarela ?? 'manual';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Configuración de Cobros y API',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montoDefaultCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Mensualidad Estándar / Defecto (MXN)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pasarela de Pagos Digitales',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: pasarelaSeleccionada,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Manual (Efectivo / Transferencia)')),
                        DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                        DropdownMenuItem(value: 'mercadopago', child: Text('Mercado Pago')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => pasarelaSeleccionada = val);
                        }
                      },
                    ),
                    if (pasarelaSeleccionada != 'manual') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: publicKeyCtrl,
                        decoration: InputDecoration(
                          labelText: 'Public Key / Client ID',
                          hintText: pasarelaSeleccionada == 'stripe' ? 'pk_live_...' : 'APP_USR-...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: secretKeyCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Secret Key / Access Token (Encriptado)',
                          hintText: pasarelaSeleccionada == 'stripe' ? 'sk_live_...' : 'APP_USR-...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: instTransferCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Instrucciones de Transferencia (CLABE/Banco)',
                        hintText: 'Ej. CLABE: 0123456789... Banco: BBVA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final montoDef = double.tryParse(montoDefaultCtrl.text.trim()) ?? 499.0;
                          final newConfig = PaymentConfig(
                            id: _paymentConfig?.id ?? '',
                            idEmpresa: _idEmpresa ?? 'GENERAL',
                            pasarela: pasarelaSeleccionada,
                            publicKey: publicKeyCtrl.text.trim(),
                            secretKeyEncrypted: secretKeyCtrl.text.trim(),
                            moneda: 'MXN',
                            montoDefault: montoDef,
                            instruccionesTransferencia: instTransferCtrl.text.trim(),
                          );
                          
                          Navigator.pop(context);
                          setState(() => _isLoading = true);
                          final ok = await _supabaseService.savePaymentConfig(newConfig);
                          if (mounted) {
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Configuración de cobros guardada ✅'),
                                  backgroundColor: Colors.black,
                                ),
                              );
                              _loadData();
                            } else {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        child: Text(
                          'Guardar Configuración',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return "${date.day} ${months[date.month - 1]}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    // Segment clients based on ClientSubscription status & days of delay
    final paidClients = _clients.where((c) {
      final sub = _subscriptionsMap[c.userID];
      if (sub == null) {
        return c.nextPaymentDate != null && c.nextPaymentDate!.isAfter(DateTime.now());
      }
      return !sub.isAtrasado;
    }).toList();

    final pendingClients = _clients.where((c) {
      final sub = _subscriptionsMap[c.userID];
      if (sub == null) {
        return c.nextPaymentDate == null || c.nextPaymentDate!.isBefore(DateTime.now());
      }
      return sub.isAtrasado;
    }).toList();

    // Stats calculations
    final double feePerClient = _paymentConfig?.montoDefault ?? 499.0;
    double totalCobrado = 0;
    for (final c in paidClients) {
      totalCobrado += _subscriptionsMap[c.userID]?.montoMensualidad ?? feePerClient;
    }

    double totalPendiente = 0;
    for (final c in pendingClients) {
      totalPendiente += _subscriptionsMap[c.userID]?.montoMensualidad ?? feePerClient;
    }

    double totalEstimado = 0;
    for (final c in _clients) {
      totalEstimado += _subscriptionsMap[c.userID]?.montoMensualidad ?? feePerClient;
    }

    // Calcular límites dinámicos para la gráfica
    final double maxVal = _revenueData.isNotEmpty ? _revenueData.reduce(max) : 0.0;
    final double minY = 0.0;
    double maxY = maxVal == 0.0 ? 5000 : maxVal * 1.2;

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
          'Finanzas',
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
                                title: 'Cobrado',
                                value: '\$${totalCobrado.toStringAsFixed(0)}',
                                subtitle: '${paidClients.length} clientes',
                                color: const Color(0xFF22C55E),
                                bgColor: const Color(0xFFF0FDF4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Pendiente',
                                value: '\$${totalPendiente.toStringAsFixed(0)}',
                                subtitle: '${pendingClients.length} clientes',
                                color: const Color(0xFFEF4444),
                                bgColor: const Color(0xFFFEF2F2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: _buildMetricCard(
                          title: 'Ingresos del Mes Actual',
                          value: '\$${(_revenueData.isNotEmpty ? _revenueData.last : 0.0).toStringAsFixed(0)} MXN',
                          subtitle: 'Total recaudado en el mes en curso',
                          color: Colors.black,
                          bgColor: Colors.white,
                          isFullWidth: true,
                        ),
                      ),

                      // 2. Premium Line Chart (Rounded borders + fine line)
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
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Historial de Ingresos',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'Evolución de facturación mensual',
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
                                            return Text(
                                              value >= 1000
                                                  ? '\$${(value / 1000).toStringAsFixed(1)}k'
                                                  : '\$${value.toStringAsFixed(0)}',
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
                                              // Mostrar etiqueta cada 10 días o en el último día
                                              if (index % 15 == 0 || index == _months.length - 1) {
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
                                        curveSmoothness: 0.45,
                                        barWidth: 2.0, // Fine line
                                        color: Colors.black,
                                        dotData: FlDotData(
                                          show: true,
                                          checkToShowDot: (spot, barData) {
                                            return spot.y > 0;
                                          },
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
                                              Colors.black.withValues(alpha: 0.08),
                                              Colors.black.withValues(alpha: 0.0),
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

                      // 3. TabBar control
                      Container(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 12),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.black,
                          labelColor: Colors.black,
                          unselectedLabelColor: const Color(0xFF737373),
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                          tabs: [
                            Tab(text: 'Pendientes (${pendingClients.length})'),
                            Tab(text: 'Al Corriente (${paidClients.length})'),
                          ],
                        ),
                      ),

                      // 4. Tab list area
                      SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Pendientes
                            _buildClientList(pendingClients, isPending: true),
                            // Tab 2: Al Corriente
                            _buildClientList(paidClients, isPending: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add_card, color: Colors.white, size: 20),
        label: Text(
          'Registrar Pago',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => _showManualPaymentModal(null),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullWidth ? const Color(0xFFE5E5E5) : color.withValues(alpha: 0.15),
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
              color: isFullWidth ? const Color(0xFF737373) : color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isFullWidth ? 20 : 18,
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

  Widget _buildClientList(List<UserProfile> list, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.pending_actions_outlined,
              size: 40,
              color: const Color(0xFFD4D4D4),
            ),
            const SizedBox(height: 12),
            Text(
              isPending ? '¡No hay cobros pendientes!' : 'No hay clientes activos en este momento',
              style: GoogleFonts.inter(color: const Color(0xFF737373), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final client = list[index];
        final sub = _subscriptionsMap[client.userID];
        final diasRetraso = sub?.diasRetraso ?? 0;
        final fechaCorte = sub?.proximaFechaPago ?? client.nextPaymentDate;
        final montoFee = sub?.montoMensualidad ?? (_paymentConfig?.montoDefault ?? 499.0);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Row(
            children: [
              // Client Avatar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientFinancesScreen(client: client),
                    ),
                  ).then((_) => _loadData());
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF5F5F5),
                  backgroundImage: client.avatarUrl != null && client.avatarUrl!.isNotEmpty
                      ? NetworkImage(client.avatarUrl!)
                      : null,
                  child: client.avatarUrl == null || client.avatarUrl!.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF737373), size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // Client Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          client.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '\$${montoFee.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: const Color(0xFF525252),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Corte: ${_formatDate(fechaCorte)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF737373),
                      ),
                    ),
                  ],
                ),
              ),

              // Status badge / Action button
              if (isPending) ...[
                // Overdue status text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    diasRetraso > 0 ? '$diasRetraso días de retraso' : 'Vence hoy',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Action: Manual payment modal
                IconButton(
                  icon: const Icon(Icons.add_card, color: Colors.black, size: 20),
                  tooltip: 'Registrar pago manual',
                  onPressed: () => _showManualPaymentModal(client),
                ),
              ] else ...[
                // Paid status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Al corriente',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF737373), size: 18),
                  tooltip: 'Ver historial de pagos',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientFinancesScreen(client: client),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
