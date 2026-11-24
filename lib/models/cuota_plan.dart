class CuotaPlan {
  final String id;
  final String deudaId;
  final DateTime fechaProgramada;
  final double montoProgramado;
  double montoPagado;
  bool pagado;
  DateTime? fechaPagoReal;
  String observaciones;
  final int orden;

  CuotaPlan({
    required this.id,
    required this.deudaId,
    required this.fechaProgramada,
    required this.montoProgramado,
    required this.montoPagado,
    required this.pagado,
    this.fechaPagoReal,
    required this.observaciones,
    required this.orden,
  });

  factory CuotaPlan.fromMap(Map<String, dynamic> map) {
    return CuotaPlan(
      id: map['id']?.toString() ?? '',
      deudaId: map['deuda_id']?.toString() ?? '',
      fechaProgramada: DateTime.tryParse(map['fecha_programada']?.toString() ?? '') ?? DateTime.now(),
      montoProgramado: (map['monto_programado'] as num?)?.toDouble() ?? 0.0,
      montoPagado: (map['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      pagado: map['pagado'] ?? false,
      fechaPagoReal: map['fecha_pago_real'] != null ? DateTime.tryParse(map['fecha_pago_real'].toString()) : null,
      observaciones: map['observaciones']?.toString() ?? '',
      orden: map['orden'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deuda_id': deudaId,
      'fecha_programada': '${fechaProgramada.year}-${fechaProgramada.month.toString().padLeft(2, '0')}-${fechaProgramada.day.toString().padLeft(2, '0')}',
      'monto_programado': montoProgramado,
      'monto_pagado': montoPagado,
      'pagado': pagado,
      if (fechaPagoReal != null)
        'fecha_pago_real': '${fechaPagoReal!.year}-${fechaPagoReal!.month.toString().padLeft(2, '0')}-${fechaPagoReal!.day.toString().padLeft(2, '0')}',
      'observaciones': observaciones,
      'orden': orden,
    };
  }
}
