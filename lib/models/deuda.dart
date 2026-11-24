class Deuda {
  final String id;
  final String nombre;
  final bool esCuotaCasa;
  final double montoTotal;
  final double saldoPendiente;
  final double cuotaMensual;
  final int? diaPago;
  final String? notas;

  Deuda({
    required this.id,
    required this.nombre,
    required this.esCuotaCasa,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.cuotaMensual,
    this.diaPago,
    this.notas,
  });

  factory Deuda.fromMap(Map<String, dynamic> map) {
    return Deuda(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre'] ?? '',
      esCuotaCasa: map['es_cuota_casa'] ?? false,
      montoTotal: (map['monto_total'] as num?)?.toDouble() ?? 0.0,
      saldoPendiente: (map['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
      cuotaMensual: (map['cuota_mensual'] as num?)?.toDouble() ?? 0.0,
      diaPago: map['dia_pago'] as int?,
      notas: map['notas'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'es_cuota_casa': esCuotaCasa,
      'monto_total': montoTotal,
      'saldo_pendiente': saldoPendiente,
      'cuota_mensual': cuotaMensual,
      if (diaPago != null) 'dia_pago': diaPago,
      if (notas != null && notas!.isNotEmpty) 'notas': notas,
    };
  }

  double get porcentajePagado {
    if (montoTotal <= 0) return 0.0;
    final pagado = montoTotal - saldoPendiente;
    final pct = pagado / montoTotal;
    return pct.clamp(0.0, 1.0);
  }
}
