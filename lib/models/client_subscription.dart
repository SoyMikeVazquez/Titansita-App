class ClientSubscription {
  final String id;
  final String clienteId;
  final String idEmpresa;
  final double montoMensualidad;
  final DateTime proximaFechaPago;
  final String estatus; // 'al_corriente', 'pendiente', 'atrasado', 'suspendido'
  final int diasGracia;
  final String? notas;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientSubscription({
    required this.id,
    required this.clienteId,
    required this.idEmpresa,
    required this.montoMensualidad,
    required this.proximaFechaPago,
    required this.estatus,
    this.diasGracia = 3,
    this.notas,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClientSubscription.fromJson(Map<String, dynamic> json) {
    final proximaFecha = json['proxima_fecha_pago'] != null
        ? DateTime.parse(json['proxima_fecha_pago'].toString())
        : DateTime.now().add(const Duration(days: 30));

    return ClientSubscription(
      id: json['id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      idEmpresa: json['IDEmpresa']?.toString() ?? '',
      montoMensualidad: (json['monto_mensualidad'] as num?)?.toDouble() ?? 499.0,
      proximaFechaPago: proximaFecha,
      estatus: json['estatus']?.toString() ?? 'al_corriente',
      diasGracia: (json['dias_gracia'] as num?)?.toInt() ?? 3,
      notas: json['notas']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'IDEmpresa': idEmpresa,
      'monto_mensualidad': montoMensualidad,
      'proxima_fecha_pago': proximaFechaPago.toIso8601String().substring(0, 10),
      'estatus': estatus,
      'dias_gracia': diasGracia,
      'notas': notas,
    };
  }

  /// Calcula los días de retraso dinámicamente respecto al día de hoy
  int get diasRetraso {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paymentDate = DateTime(proximaFechaPago.year, proximaFechaPago.month, proximaFechaPago.day);
    if (today.isAfter(paymentDate)) {
      return today.difference(paymentDate).inDays;
    }
    return 0;
  }

  /// Indica si tiene pagos vencidos
  bool get isAtrasado {
    return diasRetraso > 0;
  }

  /// Estado dinámico para visualización
  String get estatusCalculado {
    if (diasRetraso > 0) return 'atrasado';
    return estatus;
  }
}
