class GastoCasa {
  final String id;
  final String concepto;
  final String categoria;
  final double monto;
  final DateTime fecha;
  final String pagadoPor;
  final String notas;

  GastoCasa({
    required this.id,
    required this.concepto,
    required this.categoria,
    required this.monto,
    required this.fecha,
    required this.pagadoPor,
    required this.notas,
  });

  factory GastoCasa.fromMap(Map<String, dynamic> map) {
    return GastoCasa(
      id: map['id']?.toString() ?? '',
      concepto: map['concepto']?.toString() ?? '',
      categoria: map['categoria']?.toString() ?? 'Servicios',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      pagadoPor: map['pagado_por']?.toString() ?? 'Ambos',
      notas: map['notas']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'concepto': concepto,
      'categoria': categoria,
      'monto': monto,
      'fecha': '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
      'pagado_por': pagadoPor,
      'notas': notas,
    };
  }
}
