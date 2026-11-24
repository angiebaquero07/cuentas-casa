class Pago {
  final String id;
  final String deudaId;
  final double monto;
  final DateTime fecha;
  final String notas;

  Pago({
    required this.id,
    required this.deudaId,
    required this.monto,
    required this.fecha,
    required this.notas,
  });

  factory Pago.fromMap(Map<String, dynamic> map) {
    return Pago(
      id: map['id']?.toString() ?? '',
      deudaId: map['deuda_id']?.toString() ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      notas: map['notas']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deuda_id': deudaId,
      'monto': monto,
      'fecha': '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
      'notas': notas,
    };
  }
}
