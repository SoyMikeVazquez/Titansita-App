import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../services/supabase_service.dart';
import '../models/trainer.dart';
import 'package:intl/intl.dart';
import 'register_trainer_screen.dart';

class TrainersManagementScreen extends StatefulWidget {
  const TrainersManagementScreen({super.key});

  @override
  State<TrainersManagementScreen> createState() => _TrainersManagementScreenState();
}

class _TrainersManagementScreenState extends State<TrainersManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Trainer>> _activeTrainersFuture;
  late Future<List<Trainer>> _inactiveTrainersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _insertVidalTemp();
    _loadTrainers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _insertVidalTemp() async {
    try {
      final client = SupabaseService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == '5af6e447-3112-4d1a-8e45-ac0cfcb0ebf4') {
        // Intentamos buscar por user_id ya que es la columna real en EmpresasEntrenadores
        final exists = await client
            .from('EmpresasEntrenadores')
            .select()
            .or('user_id.eq.$userId,userID.eq.$userId')
            .maybeSingle();
        if (exists == null) {
          const empresaId = 'VC89ABCD';
          // Insertamos usando 'user_id' para evitar el error de columna inexistente
          await client.from('EmpresasEntrenadores').insert({
            'IDEmpresa': empresaId,
            'nombre': 'Vidal Cavazos',
            'correo_electronico': 'vidalcavazos@gmail.com',
            'telefono': 5555555555,
            'user_id': userId,
          });
          await client
              .from('users')
              .update({'IDEmpresa': empresaId})
              .eq('userID', userId!);
          if (mounted) {
            setState(() {
              _loadTrainers();
            });
          }
        }
      }
    } catch (e) {
      print('Error al insertar fila temporal de Vidal: $e');
    }
  }

  void _loadTrainers() {
    _activeTrainersFuture = SupabaseService().getTrainers();
    _inactiveTrainersFuture = SupabaseService().getInactiveTrainers();
  }

  @override
  Widget build(BuildContext context) {
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
          'Gestión de Entrenadores',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterTrainerScreen(),
                  ),
                );
                if (result == true && mounted) {
                  setState(() => _loadTrainers());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Nuevo',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.black,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Activos'),
            Tab(text: 'Inactivos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrainersList(_activeTrainersFuture, isActiveTab: true),
          _buildTrainersList(_inactiveTrainersFuture, isActiveTab: false),
        ],
      ),
    );
  }

  Widget _buildTrainersList(Future<List<Trainer>> future, {required bool isActiveTab}) {
    return FutureBuilder<List<Trainer>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final trainers = snapshot.data ?? [];

        if (trainers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActiveTab ? Icons.people_outline : Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  isActiveTab
                      ? 'No hay entrenadores activos'
                      : 'No hay entrenadores inactivos',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isActiveTab) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterTrainerScreen(),
                        ),
                      );
                      if (result == true && mounted) {
                        setState(() => _loadTrainers());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text('Agregar Entrenador', style: GoogleFonts.inter()),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trainers.length,
          itemBuilder: (context, index) =>
              _buildTrainerCard(trainers[index], isActiveTab: isActiveTab),
        );
      },
    );
  }

  Widget _buildTrainerCard(Trainer trainer, {required bool isActiveTab}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto
                if (trainer.fotoPerfil != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      trainer.fotoPerfil!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                    ),
                  )
                else
                  _buildPlaceholderAvatar(),
                const SizedBox(width: 12),
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trainer.nombre,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (trainer.isSuperAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Super Admin',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActiveTab
                              ? const Color(0xFFDEF7EC)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isActiveTab ? 'activo' : 'inactivo',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActiveTab
                                ? const Color(0xFF065F46)
                                : const Color(0xFF7F1D1D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menú
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'editar') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showEditDialog(trainer);
                      });
                    } else if (value == 'password') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _handleTrainerPasswordAccess(trainer);
                      });
                    } else if (value == 'suspender') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showDeleteDialog(trainer);
                      });
                    } else if (value == 'reactivar') {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showReactivateDialog(trainer);
                      });
                    }
                  },
                  itemBuilder: (context) => isActiveTab
                      ? [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Text('Editar'),
                          ),
                          const PopupMenuItem(
                            value: 'password',
                            child: Row(
                              children: [
                                Icon(Icons.key_outlined, size: 18, color: Colors.black87),
                                SizedBox(width: 8),
                                Text('Ver / Editar Contraseña'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'suspender',
                            child: Text('Suspender'),
                          ),
                        ]
                      : [
                          const PopupMenuItem(
                            value: 'password',
                            child: Row(
                              children: [
                                Icon(Icons.key_outlined, size: 18, color: Colors.black87),
                                SizedBox(width: 8),
                                Text('Ver / Editar Contraseña'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reactivar',
                            child: Text('Reactivar'),
                          ),
                        ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Detalles
            _buildInfoRow(Icons.email_outlined, trainer.correoElectronico),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone_outlined, trainer.telefono),
            if (trainer.especialidad.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.work_outline, trainer.especialidad),
            ],
            if (trainer.bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trainer.bio,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.person, color: Colors.grey[400], size: 32),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(Trainer trainer) {
    final nameController = TextEditingController(text: trainer.nombre);
    final phoneController = TextEditingController(text: trainer.telefono);
    final specialtyController = TextEditingController(text: trainer.especialidad);
    final bioController = TextEditingController(text: trainer.bio);
    bool isSuperAdmin = trainer.isSuperAdmin;

    // Payment fields state in dialog
    DateTime? fechaPago = trainer.fechaPago ?? DateTime.now();
    String modalidadPago = trainer.modalidadPago ?? 'mensual';
    final montoController = TextEditingController(text: trainer.montodecobroMensual.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Editar Entrenador', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(nameController, 'Nombre completo'),
                const SizedBox(height: 12),
                _buildDialogTextField(phoneController, 'Teléfono'),
                const SizedBox(height: 12),
                _buildDialogTextField(specialtyController, 'Especialidad'),
                const SizedBox(height: 12),
                _buildDialogTextField(bioController, 'Biografía', maxLines: 3),
                const SizedBox(height: 16),

                // COBRO SECTION
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'INFORMACIÓN DE COBRO',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 8),

                // Date Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fecha Pago Inicial', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600])),
                          const SizedBox(height: 2),
                          Text(
                            fechaPago != null ? DateFormat('dd/MM/yyyy').format(fechaPago!) : 'Elegir fecha',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, size: 20, color: Colors.black),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaPago ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.black,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              fechaPago = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Modality selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: DropdownButtonFormField<String>(
                    dropdownColor: Colors.white,
                    value: modalidadPago,
                    style: GoogleFonts.inter(color: Colors.black, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Modalidad de Pago',
                      labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                      DropdownMenuItem(value: 'bimestral', child: Text('Bimestral')),
                      DropdownMenuItem(value: 'trimestral', child: Text('Trimestral')),
                      DropdownMenuItem(value: 'semestral', child: Text('Semestral')),
                      DropdownMenuItem(value: 'anual', child: Text('Anual')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          modalidadPago = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Monthly charge input
                _buildDialogTextField(montoController, 'Monto de Cobro Mensual (\$)'),
                const SizedBox(height: 16),

                // SuperAdmin toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: isSuperAdmin ? const Color(0xFF92400E) : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Administrador',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Otorga acceso total al sistema',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF737373),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isSuperAdmin,
                        onChanged: (val) {
                          setDialogState(() {
                            isSuperAdmin = val;
                          });
                        },
                        activeColor: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(montoController.text.trim()) ?? 0.0;

                DateTime proximoPago = fechaPago ?? DateTime.now();
                if (modalidadPago == 'mensual') {
                  proximoPago = DateTime(proximoPago.year, proximoPago.month + 1, proximoPago.day);
                } else if (modalidadPago == 'bimestral') {
                  proximoPago = DateTime(proximoPago.year, proximoPago.month + 2, proximoPago.day);
                } else if (modalidadPago == 'trimestral') {
                  proximoPago = DateTime(proximoPago.year, proximoPago.month + 3, proximoPago.day);
                } else if (modalidadPago == 'semestral') {
                  proximoPago = DateTime(proximoPago.year, proximoPago.month + 6, proximoPago.day);
                } else if (modalidadPago == 'anual') {
                  proximoPago = DateTime(proximoPago.year + 1, proximoPago.month, proximoPago.day);
                }

                await SupabaseService().updateTrainer(
                  trainerId: trainer.id,
                  nombre: nameController.text.trim(),
                  telefono: phoneController.text.trim(),
                  especialidad: specialtyController.text.trim(),
                  bio: bioController.text.trim(),
                  isSuperAdmin: isSuperAdmin,
                  fechaPago: fechaPago,
                  modalidadPago: modalidadPago,
                  proximoPago: proximoPago,
                  montodecobroMensual: monto,
                );
                if (mounted) {
                  Navigator.pop(context);
                  setState(() => _loadTrainers());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text('Guardar', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _showDeleteDialog(Trainer trainer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Suspender entrenador?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Se inhabilitará a ${trainer.nombre} del sistema. Ya no aparecerá en la lista activa.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar primer diálogo
              _showConfirmSuspendDialog(trainer); // Mostrar segunda confirmación
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Suspender', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmSuspendDialog(Trainer trainer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Confirmación de Seguridad', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.orange[900])),
        content: Text(
          '¿Estás COMPLETAMENTE seguro de inhabilitar a ${trainer.nombre}? Esta es una acción de alta importancia.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService().deleteTrainer(trainer.id);
              if (mounted) {
                Navigator.pop(context); // Cerrar segundo diálogo
                setState(() => _loadTrainers());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
            ),
            child: Text('Sí, inhabilitar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReactivateDialog(Trainer trainer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Reactivar entrenador?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          '${trainer.nombre} podrá volver a acceder al sistema y aparecerá en la lista activa.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await SupabaseService().reactivateTrainer(trainer.id);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${trainer.nombre} ha sido reactivado ✅',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: Colors.black,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
                setState(() => _loadTrainers());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
            ),
            child: Text('Reactivar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _authenticateAdmin() async {
    // 1. Intentar Autenticación Biométrica (FaceID / Huella / PIN de Dispositivo) si está disponible
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final bool canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (canCheck) {
        final bool didAuthenticate = await localAuth.authenticate(
          localizedReason: 'Autentícate con Face ID o Huella para acceder a la contraseña del entrenador',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
        if (didAuthenticate) {
          return true;
        }
      }
    } catch (e) {
      print('Biometría no disponible o denegada: $e');
    }

    // 2. Fallback: Requerir y VERIFICAR la Contraseña REAL del Administrador actualmente autenticado
    if (!mounted) return false;
    final passController = TextEditingController();
    bool authenticated = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isObscured = true;
        bool isVerifying = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.black),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Autenticación Requerida',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por motivos de seguridad, ingresa la Contraseña del Administrador actual para desbloquear la clave del entrenador.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: isObscured,
                    keyboardType: TextInputType.text,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña de Administrador',
                      hintText: 'Ingresa tu contraseña actual',
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => isObscured = !isObscured),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey[600])),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text('Verificar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final entered = passController.text.trim();
                          if (entered.isEmpty) {
                            setDialogState(() => errorText = 'Ingresa tu contraseña de administrador');
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            errorText = null;
                          });

                          // VERIFICACIÓN REAL contra Supabase
                          final isValid = await SupabaseService().verifyCurrentAdminPassword(entered);

                          if (context.mounted) {
                            if (isValid) {
                              authenticated = true;
                              Navigator.pop(context);
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                                errorText = 'Contraseña de administrador incorrecta';
                              });
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    return authenticated;
  }

  Future<void> _handleTrainerPasswordAccess(Trainer trainer) async {
    final ok = await _authenticateAdmin();
    if (!ok) return;

    // Mostrar diálogo de cargando contraseña
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.black)),
    );

    final currentPassword = await SupabaseService().getTrainerPassword(
      trainer.userId,
      email: trainer.correoElectronico,
    );

    if (mounted) {
      Navigator.pop(context); // Cerrar loader
    }

    if (!mounted) return;

    final passController = TextEditingController(text: currentPassword ?? '');
    bool isVisible = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.key_outlined, color: Colors.black),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Contraseña de ${trainer.nombre}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trainer.correoElectronico,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: !isVisible,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      letterSpacing: isVisible ? 0 : 2,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Contraseña del Entrenador',
                      hintText: currentPassword == null ? 'Sin contraseña registrada' : '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          setModalState(() => isVisible = !isVisible);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                isVisible ? Icons.visibility_off : Icons.visibility,
                                color: Colors.black,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVisible ? 'Ocultar Contraseña' : 'Mostrar Contraseña',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          if (passController.text.isNotEmpty) {
                            Clipboard.setData(
                              ClipboardData(text: passController.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Contraseña copiada al portapapeles 📋'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined, size: 16, color: Colors.black),
                        label: Text(
                          'Copiar',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newPass = passController.text.trim();
                              if (newPass.isEmpty) return;

                              setModalState(() => isSaving = true);

                              final errorMsg = await SupabaseService().updateTrainerPassword(
                                userId: trainer.userId,
                                email: trainer.correoElectronico,
                                newPassword: newPass,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                if (errorMsg == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Contraseña actualizada exitosamente para ${trainer.nombre} ✅',
                                      ),
                                      backgroundColor: Colors.black,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error: $errorMsg',
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Guardar Nueva Contraseña',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
