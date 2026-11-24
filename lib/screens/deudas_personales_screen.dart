import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deuda.dart';

class DeudasPersonalesScreen extends StatefulWidget {
  const DeudasPersonalesScreen({super.key});

  @override
  State<DeudasPersonalesScreen> createState() => _DeudasPersonalesScreenState();
}

class _DeudasPersonalesScreenState extends State<DeudasPersonalesScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$ ', decimalDigits: 0);
  List<Deuda> _deudas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDeudas();
  }

  Future<void> _cargarDeudas() async {
    setState(() => _isLoading = true);
    try {
      // Cargar ÚNICAMENTE las deudas que NO sean de la casa
      final response = await Supabase.instance.client
          .from('deudas')
          .select()
          .eq('es_cuota_casa', false)
          .order('saldo_pendiente', ascending: false);

      final lista = (response as List).map((item) => Deuda.fromMap(item)).toList();
      setState(() {
        _deudas = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error al cargar deudas: $e')),
        );
      }
    }
  }

  double get _totalSaldoDeudas => _deudas.fold<double>(0, (sum, d) => sum + d.saldoPendiente);
  double get _totalCuotasMensuales => _deudas.fold<double>(0, (sum, d) => sum + d.cuotaMensual);

  Future<void> _registrarAbono(Deuda deuda, double monto) async {
    try {
      final nuevoSaldo = (deuda.saldoPendiente - monto).clamp(0.0, double.infinity);

      await Supabase.instance.client.from('pagos').insert({
        'deuda_id': deuda.id,
        'monto': monto,
        'fecha': DateTime.now().toIso8601String().split('T').first,
        'notas': 'Abono deuda personal',
      });

      await Supabase.instance.client
          .from('deudas')
          .update({'saldo_pendiente': nuevoSaldo})
          .eq('id', deuda.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('¡Abono de ${_currencyFormat.format(monto)} registrado!'),
          ),
        );
      }
      _cargarDeudas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _eliminarDeuda(Deuda deuda) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text('¿Seguro que deseas eliminar "${deuda.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('deudas').delete().eq('id', deuda.id);
      _cargarDeudas();
    }
  }

  void _mostrarDialogoAbono(Deuda deuda) {
    final controller = TextEditingController(text: deuda.cuotaMensual > 0 ? deuda.cuotaMensual.toInt().toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Abonar a ${deuda.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo actual: ${_currencyFormat.format(deuda.saldoPendiente)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto a abonar',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final monto = _parsearMonto(controller.text);
              if (monto > 0) {
                Navigator.pop(ctx);
                _registrarAbono(deuda, monto);
              }
            },
            child: const Text('Registrar Abono'),
          ),
        ],
      ),
    );
  }

  double _parsearMonto(String texto) {
    final limpio = texto.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(limpio) ?? 0.0;
  }

  void _mostrarDialogoCrearDeuda() {
    final nombreCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final saldoCtrl = TextEditingController();
    final cuotaCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    final notasCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nueva Deuda / Crédito',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre (ej: Tarjeta Bancolombia, Préstamo Carro)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: totalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto Total',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: saldoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Saldo Pendiente',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cuotaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cuota Mensual',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: diaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Día de Pago (1-31)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas adicionales (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar Deuda'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  if (nombreCtrl.text.trim().isEmpty) return;
                  final total = _parsearMonto(totalCtrl.text);
                  final saldo = saldoCtrl.text.isNotEmpty ? _parsearMonto(saldoCtrl.text) : total;
                  final cuota = _parsearMonto(cuotaCtrl.text);
                  final dia = int.tryParse(diaCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                  final nueva = Deuda(
                    id: '',
                    nombre: nombreCtrl.text.trim(),
                    esCuotaCasa: false, // ¡Nunca de la casa!
                    montoTotal: total,
                    saldoPendiente: saldo,
                    cuotaMensual: cuota,
                    diaPago: dia,
                    notas: notasCtrl.text.trim(),
                  );

                  await Supabase.instance.client.from('deudas').insert(nueva.toMap());
                  if (ctx.mounted) Navigator.pop(ctx);
                  _cargarDeudas();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Mis Deudas Personales', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDeudas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Deuda', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _mostrarDialogoCrearDeuda,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDeudas,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // TARJETAS DE RESUMEN EXCLUSIVO DE DEUDAS PERSONALES
                  Row(
                    children: [
                      Expanded(
                        child: _buildResumenCard(
                          'Total Deudas Personales',
                          _currencyFormat.format(_totalSaldoDeudas),
                          Icons.credit_card_off,
                          const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildResumenCard(
                          'Cuotas Mensuales',
                          _currencyFormat.format(_totalCuotasMensuales),
                          Icons.calendar_month,
                          const Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lista de Deudas y Créditos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text('${_deudas.length} activas', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_deudas.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                          SizedBox(height: 12),
                          Text('¡No tienes deudas personales registradas!',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Toca "+ Nueva Deuda" para agregar tarjetas o créditos.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ..._deudas.map((deuda) => _buildDeudaCard(deuda)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildResumenCard(String titulo, String monto, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(monto, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeudaCard(Deuda deuda) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          child: const Icon(Icons.credit_card, color: Color(0xFF1E88E5)),
        ),
        title: Text(deuda.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Saldo: ${_currencyFormat.format(deuda.saldoPendiente)}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
            if (deuda.cuotaMensual > 0)
              Text(
                'Cuota: ${_currencyFormat.format(deuda.cuotaMensual)}${deuda.diaPago != null ? ' (Día ${deuda.diaPago})' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF43A047)),
              tooltip: 'Abonar a esta deuda',
              onPressed: () => _mostrarDialogoAbono(deuda),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: 'Eliminar',
              onPressed: () => _eliminarDeuda(deuda),
            ),
          ],
        ),
      ),
    );
  }
}
