import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deuda.dart';
import '../models/cuota_plan.dart';

class CasaDetalleScreen extends StatefulWidget {
  final Deuda casa;

  const CasaDetalleScreen({super.key, required this.casa});

  @override
  State<CasaDetalleScreen> createState() => _CasaDetalleScreenState();
}

class _CasaDetalleScreenState extends State<CasaDetalleScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final _dateFormat = DateFormat('dd-MMM-yy', 'es_CO');
  List<CuotaPlan> _cuotas = [];
  bool _isLoading = true;
  String _filtro = 'Todas'; // 'Todas', 'Pendientes', 'Pagadas'
  late double _valorTotalCasa;

  @override
  void initState() {
    super.initState();
    _valorTotalCasa = widget.casa.montoTotal > 0 ? widget.casa.montoTotal : 175000000;
    _cargarPlan();
  }

  Future<void> _cargarPlan() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('plan_casa')
          .select()
          .order('orden', ascending: true);

      final lista = (response as List).map((item) => CuotaPlan.fromMap(item)).toList();
      setState(() {
        _cuotas = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error al cargar plan de pagos: $e')),
        );
      }
    }
  }

  double get _totalPagado => _cuotas
      .where((c) => c.pagado)
      .fold<double>(0, (sum, c) => sum + (c.montoPagado > 0 ? c.montoPagado : c.montoProgramado));

  double get _saldoPendiente => (_valorTotalCasa - _totalPagado).clamp(0, double.infinity);
  double get _progreso => _valorTotalCasa > 0 ? (_totalPagado / _valorTotalCasa).clamp(0.0, 1.0) : 0.0;
  int get _cuotasPagadasCount => _cuotas.where((c) => c.pagado).length;

  Future<void> _actualizarSaldoEnDeuda() async {
    try {
      await Supabase.instance.client.from('deudas').update({
        'monto_total': _valorTotalCasa,
        'saldo_pendiente': _saldoPendiente,
      }).eq('id', widget.casa.id);
    } catch (_) {}
  }

  Future<void> _togglePagoRapido(CuotaPlan cuota) async {
    final nuevoEstado = !cuota.pagado;
    final nuevoMonto = nuevoEstado ? (cuota.montoPagado > 0 ? cuota.montoPagado : cuota.montoProgramado) : 0.0;

    setState(() {
      cuota.pagado = nuevoEstado;
      cuota.montoPagado = nuevoMonto;
      cuota.fechaPagoReal = nuevoEstado ? DateTime.now() : null;
    });

    await Supabase.instance.client.from('plan_casa').update({
      'pagado': cuota.pagado,
      'monto_pagado': cuota.montoPagado,
      'fecha_pago_real': cuota.fechaPagoReal?.toIso8601String().split('T').first,
    }).eq('id', cuota.id);

    await _actualizarSaldoEnDeuda();
  }

  void _mostrarDialogoEditarCuota(CuotaPlan cuota) {
    final montoCtrl = TextEditingController(
      text: (cuota.montoPagado > 0 ? cuota.montoPagado : cuota.montoProgramado).toInt().toString(),
    );
    final obsCtrl = TextEditingController(text: cuota.observaciones);
    bool estaPagado = cuota.pagado;
    DateTime fechaReal = cuota.fechaPagoReal ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Cuota ${_dateFormat.format(cuota.fechaProgramada)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valor programado original: ${_currencyFormat.format(cuota.montoProgramado)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Switch de estado
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Listo, ya se pagó?', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(estaPagado ? 'Marcada como CANCELADA' : 'Marcada como PENDIENTE'),
                  value: estaPagado,
                  activeColor: const Color(0xFF4A148C), // ignore: deprecated_member_use
                  onChanged: (val) => setDlgState(() => estaPagado = val),
                ),
                const SizedBox(height: 12),

                // Campo de Monto Real Cancelado
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor realmente cancelado',
                    helperText: 'Puedes cambiar el valor si abonaste más o menos',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Selector de Fecha en que se pagó (si está pagado)
                if (estaPagado) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available, color: Colors.green),
                    title: const Text('Fecha en que se pagó', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(fechaReal),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fechaReal,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDlgState(() => fechaReal = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Observaciones
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
              onPressed: () async {
                final valorIngresado =
                    double.tryParse(montoCtrl.text.replaceAll(',', '').replaceAll('.', '')) ?? cuota.montoProgramado;

                setState(() {
                  cuota.pagado = estaPagado;
                  cuota.montoPagado = estaPagado ? valorIngresado : 0.0;
                  cuota.fechaPagoReal = estaPagado ? fechaReal : null;
                  cuota.observaciones = obsCtrl.text.trim();
                });

                await Supabase.instance.client.from('plan_casa').update({
                  'pagado': cuota.pagado,
                  'monto_pagado': cuota.montoPagado,
                  'fecha_pago_real': cuota.fechaPagoReal?.toIso8601String().split('T').first,
                  'observaciones': cuota.observaciones,
                }).eq('id', cuota.id);

                await _actualizarSaldoEnDeuda();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuotasFiltradas = _cuotas.where((c) {
      if (_filtro == 'Pendientes') return !c.pagado;
      if (_filtro == 'Pagadas') return c.pagado;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        title: const Text('Plan de Pagos - Casa', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarPlan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarPlan,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // TARJETA PRINCIPAL DEL PLAN
                  _buildHeaderResumen(),
                  const SizedBox(height: 18),

                  // FILTROS
                  Row(
                    children: [
                      _buildFiltroChip('Todas', '(${_cuotas.length})'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Pendientes', '(${_cuotas.length - _cuotasPagadasCount})'),
                      const SizedBox(width: 8),
                      _buildFiltroChip('Pagadas', '($_cuotasPagadasCount)'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ENCABEZADO DE TABLA ESTILO PURPLE
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Row(
                      children: [
                        SizedBox(width: 32, child: Icon(Icons.check_circle_outline, color: Colors.white70, size: 20)),
                        SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'MES / FECHA',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'VALOR',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'OBSERVACIONES',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FILAS DE CUOTAS
                  if (cuotasFiltradas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      alignment: Alignment.center,
                      child: Text('No hay cuotas con el filtro "$_filtro"'),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(cuotasFiltradas.length, (index) {
                          final cuota = cuotasFiltradas[index];
                          final esPar = index % 2 == 1;
                          final colorFondo = cuota.pagado
                              ? const Color(0xFFE8F5E9) // verde suave si está pagado
                              : (esPar ? const Color(0xFFF3E5F5) : Colors.white);

                          final montoMostrar = cuota.pagado && cuota.montoPagado > 0
                              ? cuota.montoPagado
                              : cuota.montoProgramado;

                          return InkWell(
                            onTap: () => _mostrarDialogoEditarCuota(cuota),
                            child: Container(
                              color: colorFondo,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Checkbox interactivo rápido
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        cuota.pagado ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: cuota.pagado ? Colors.green.shade700 : Colors.grey.shade400,
                                        size: 24,
                                      ),
                                      tooltip: cuota.pagado ? 'Desmarcar pago' : 'Marcar como pagado',
                                      onPressed: () => _togglePagoRapido(cuota),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Fecha / Mes
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _dateFormat.format(cuota.fechaProgramada),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        decoration: cuota.pagado ? TextDecoration.lineThrough : null,
                                        color: cuota.pagado ? Colors.green.shade900 : Colors.black87,
                                      ),
                                    ),
                                  ),

                                  // Valor Cancelado
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      _currencyFormat.format(montoMostrar),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: cuota.pagado ? const Color(0xFF2E7D32) : const Color(0xFF4A148C),
                                      ),
                                    ),
                                  ),

                                  // Observaciones
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      cuota.observaciones.isNotEmpty
                                          ? cuota.observaciones
                                          : (cuota.pagado ? 'PAGADO' : '-'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: cuota.observaciones.contains('INICIAL')
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: cuota.observaciones.contains('INICIAL')
                                            ? const Color(0xFF6A1B9A)
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltroChip(String label, String conteo) {
    final seleccionado = _filtro == label;
    return ChoiceChip(
      label: Text('$label $conteo'),
      selected: seleccionado,
      selectedColor: const Color(0xFF4A148C),
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _filtro = label);
      },
    );
  }

  Widget _buildHeaderResumen() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.home, color: Colors.white, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Valor Total Casa',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_cuotasPagadasCount de ${_cuotas.length} cuotas',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(_valorTotalCasa),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Divider(color: Colors.white24, height: 26),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Cancelado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_totalPagado),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF69F0AE)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo Pendiente', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_saldoPendiente),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barra de progreso interactiva
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progreso,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF69F0AE)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Meta: Casa 100% Pagada', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${(_progreso * 100).toStringAsFixed(1)}% pagado',
                style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
