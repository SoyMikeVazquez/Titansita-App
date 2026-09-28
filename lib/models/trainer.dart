class Trainer {
  final String id;
  final String userId;
  final String nombre;
  final String correoElectronico;
  final String telefono;
  final String especialidad;
  final String bio;
  final String? fotoPerfil;
  final String estado;
  final bool isSuperAdmin;
  final double progreso;
  final DateTime? fechaPago;
  final String? modalidadPago;
  final DateTime? proximoPago;
  final double montodecobroMensual;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trainer({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.correoElectronico,
    required this.telefono,
    this.especialidad = '',
    this.bio = '',
    this.fotoPerfil,
    this.estado = 'activo',
    this.isSuperAdmin = false,
    this.progreso = 0.0,
    this.fechaPago,
    this.modalidadPago,
    this.proximoPago,
    this.montodecobroMensual = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: (json['IDEmpresa'] ?? json['id'] ?? '').toString(),
      userId: (json['userID'] ?? json['user_id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      correoElectronico: (json['correo_electronico'] ?? json['email'] ?? '').toString(),
      telefono: json['telefono']?.toString() ?? '',
      especialidad: (json['especialidad'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      fotoPerfil: json['foto perfil']?.toString() ?? json['foto_perfil']?.toString(),
      estado: (json['estado'] ?? 'activo').toString(),
      isSuperAdmin: json['superAdmin'] == true,
      progreso: (json['progreso'] as num?)?.toDouble() ?? 0.0,
      fechaPago: json['fecha_pago'] != null ? DateTime.parse(json['fecha_pago'] as String) : null,
      modalidadPago: json['modalidad_pago']?.toString(),
      proximoPago: json['proximo_pago'] != null ? DateTime.parse(json['proximo_pago'] as String) : null,
      montodecobroMensual: (json['montodecobro_mensual'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Creates a copy of this Trainer with optional field overrides.
  Trainer copyWith({
    bool? isSuperAdmin,
    double? progreso,
    DateTime? fechaPago,
    String? modalidadPago,
    DateTime? proximoPago,
    double? montodecobroMensual,
  }) {
    return Trainer(
      id: id,
      userId: userId,
      nombre: nombre,
      correoElectronico: correoElectronico,
      telefono: telefono,
      especialidad: especialidad,
      bio: bio,
      fotoPerfil: fotoPerfil,
      estado: estado,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      progreso: progreso ?? this.progreso,
      fechaPago: fechaPago ?? this.fechaPago,
      modalidadPago: modalidadPago ?? this.modalidadPago,
      proximoPago: proximoPago ?? this.proximoPago,
      montodecobroMensual: montodecobroMensual ?? this.montodecobroMensual,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'IDEmpresa': id,
      'id': id,
      'userID': userId,
      'nombre': nombre,
      'correo_electronico': correoElectronico,
      'telefono': telefono,
      'especialidad': especialidad,
      'bio': bio,
      'foto perfil': fotoPerfil,
      'foto_perfil': fotoPerfil,
      'estado': estado,
      'superAdmin': isSuperAdmin,
      'progreso': progreso,
      'fecha_pago': fechaPago?.toIso8601String(),
      'modalidad_pago': modalidadPago,
      'proximo_pago': proximoPago?.toIso8601String(),
      'montodecobro_mensual': montodecobroMensual,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
