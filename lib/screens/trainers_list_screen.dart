import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../models/trainer.dart';

class TrainersListScreen extends StatefulWidget {
  const TrainersListScreen({super.key});

  @override
  State<TrainersListScreen> createState() => _TrainersListScreenState();
}

class _TrainersListScreenState extends State<TrainersListScreen> {
  late Future<List<Trainer>> _trainersFuture;

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  void _loadTrainers() {
    _trainersFuture = SupabaseService().getTrainers();
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
          'Entrenadores Registrados',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Trainer>>(
        future: _trainersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                    Icons.person_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay entrenadores registrados',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final trainer = trainers[index];
              return _buildTrainerCard(trainer);
            },
          );
        },
      ),
    );
  }

  Widget _buildTrainerCard(Trainer trainer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con nombre y estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainer.nombre,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: trainer.estado == 'activo'
                                  ? const Color(0xFFDEF7EC)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trainer.estado,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: trainer.estado == 'activo'
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF7F1D1D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Editar'),
                          onTap: () => _showEditDialog(trainer),
                        ),
                        PopupMenuItem(
                          child: const Text('Suspender'),
                          onTap: () => _showDeleteDialog(trainer),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Información de contacto
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  value: trainer.correoElectronico,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: trainer.telefono ?? '',
                ),
                if (trainer.especialidad != null && trainer.especialidad!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.work_outline,
                    label: 'Especialidad',
                    value: trainer.especialidad!,
                  ),
                ],
                if (trainer.bio != null && trainer.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: const Color(0xFF737373),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bio',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF737373),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trainer.bio!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.black,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF737373),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF737373),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditDialog(Trainer trainer) {
    final nameController = TextEditingController(text: trainer.nombre);
    final phoneController = TextEditingController(text: trainer.telefono);
    final specialtyController = TextEditingController(text: trainer.especialidad);
    final bioController = TextEditingController(text: trainer.bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Editar Entrenador',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditTextField(nameController, 'Nombre'),
              const SizedBox(height: 12),
              _buildEditTextField(phoneController, 'Teléfono'),
              const SizedBox(height: 12),
              _buildEditTextField(specialtyController, 'Especialidad'),
              const SizedBox(height: 12),
              _buildEditTextField(bioController, 'Biografía', maxLines: 3),
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
              await SupabaseService().updateTrainer(
                trainerId: trainer.id,
                nombre: nameController.text,
                telefono: phoneController.text,
                especialidad: specialtyController.text,
                bio: bioController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                setState(() => _loadTrainers());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: Text('Guardar', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
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
}
