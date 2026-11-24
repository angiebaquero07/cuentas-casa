import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deuda.dart';
import '../supabase_config.dart';
import 'pin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  List<Deuda> _deudas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDeudas();
  }

  bool get _isConfigured =>
      SupabaseConfig.supabaseUrl != 'TU_SUPABASE_URL_AQUI' &&
      SupabaseConfig.supabaseAnonKey != 'TU_SUPABASE_ANON_KEY_AQUI';

  Future<void> _cargarDeudas() async {
    if (!_isConfigured) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Falta configurar la URL y la Anon Key de Supabase en lib/supabase_config.dart';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('deudas')
          .select()
          .order('es_cuota_casa', ascending: false)
          .order('saldo_pendiente', ascending: false);

      final lista = (response as List).map((item) => Deuda.fromMap(item)).toList();
      setState(() {
        _deudas = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar deudas: $e';
      });
    }
  }

  Future<void> _registrarPago(Deuda deuda, double monto) async {
    try {
      final nuevoSaldo = (deuda.saldoPendiente - monto).clamp(0.0, double.infinity);

      // Guardar el abono en la tabla 'pagos'
      await Supabase.instance.client.from('pagos').insert({
        'deuda_id': deuda.id,
        'monto': monto,
        'fecha': DateTime.now().toIso8601String().split('T').first,
      });

      // Actualizar el saldo pendiente en 'deudas'
      await Supabase.instance.client
          .from('deudas')
          .update({'saldo_pendiente': nuevoSaldo})
          .eq('id', deuda.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('¡Abono de ${_currencyFormat.format(monto)} registrado con éxito!'),
          ),
        );
      }
      _cargarDeudas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade700, content: Text('Error: $e')),
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
              final monto = double.tryParse(controller.text.replaceAll(',', '').replaceAll('.', '')) ?? 0.0;
              if (monto > 0) {
                Navigator.pop(ctx);
                _registrarPago(deuda, monto);
              }
            },
            child: const Text('Registrar Pago'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCrearDeuda() {
    final nombreCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final saldoCtrl = TextEditingController();
    final cuotaCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    bool esCasa = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('¿Es la cuota de la casa / hipoteca?'),
                  subtitle: const Text('Tendrá una sección destacada especial'),
                  value: esCasa,
                  secondary: const Icon(Icons.home, color: Color(0xFF1E88E5)),
                  onChanged: (val) => setModalState(() => esCasa = val),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o Banco (ej: Crédito Casa Bancolombia)',
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
                          labelText: 'Monto Total Prestado',
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
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) return;
                    final total = double.tryParse(totalCtrl.text) ?? 0.0;
                    final saldo = double.tryParse(saldoCtrl.text) ?? total;
                    final cuota = double.tryParse(cuotaCtrl.text) ?? 0.0;
                    final dia = int.tryParse(diaCtrl.text);

                    final nueva = Deuda(
                      id: '',
                      nombre: nombreCtrl.text.trim(),
                      esCuotaCasa: esCasa,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deudasCasa = _deudas.where((d) => d.esCuotaCasa).toList();
    final otrasDeudas = _deudas.where((d) => !d.esCuotaCasa).toList();

    final totalDeuda = _deudas.fold<double>(0, (sum, d) => sum + d.saldoPendiente);
    final totalCuotaMensual = _deudas.fold<double>(0, (sum, d) => sum + d.cuotaMensual);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Color(0xFF1E88E5)),
            SizedBox(width: 10),
            Text('Mis Cuentas & Deudas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            tooltip: 'Actualizar',
            onPressed: _cargarDeudas,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.black87),
            tooltip: 'Bloquear app',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PinScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            tooltip: 'Opciones',
            onSelected: (val) {
              if (val == 'cambiar_pin') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PinScreen(cambiarPin: true)),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cambiar_pin',
                child: Row(
                  children: [
                    Icon(Icons.password, size: 20),
                    SizedBox(width: 8),
                    Text('Cambiar PIN'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E88E5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Deuda', style: TextStyle(color: Colors.white)),
        onPressed: _isConfigured ? _mostrarDialogoCrearDeuda : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _cargarDeudas, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDeudas,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      // Tarjetas de Resumen General
                      Row(
                        children: [
                          Expanded(
                            child: _buildResumenCard(
                              'Saldo Total Deudas',
                              _currencyFormat.format(totalDeuda),
                              Icons.trending_down,
                              const Color(0xFFE53935),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildResumenCard(
                              'Total Cuotas / Mes',
                              _currencyFormat.format(totalCuotaMensual),
                              Icons.calendar_month,
                              const Color(0xFF1E88E5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN DESTACADA: CUOTA DE LA CASA
                      if (deudasCasa.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.home_work, color: Color(0xFF1565C0)),
                            SizedBox(width: 8),
                            Text(
                              'Cuota de la Casa',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...deudasCasa.map((casa) => _buildCasaCard(casa)),
                        const SizedBox(height: 24),
                      ],

                      // SECCIÓN DE OTRAS DEUDAS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Otras Deudas y Créditos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text('${otrasDeudas.length} activas', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (otrasDeudas.isEmpty && deudasCasa.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                              SizedBox(height: 12),
                              Text('¡No tienes deudas registradas!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              Text('Toca "Nueva Deuda" para agregar la primera.',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      else
                        ...otrasDeudas.map((deuda) => _buildDeudaGeneralCard(deuda)),
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
          Text(titulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(monto, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildCasaCard(Deuda casa) {
    final progreso = casa.porcentajePagado;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1976D2).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      casa.nombre,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (val) {
                    if (val == 'eliminar') _eliminarDeuda(casa);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cuota Mensual', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(casa.cuotaMensual),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                if (casa.diaPago != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Día ${casa.diaPago} de cada mes',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // Barra de progreso de amortización
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF69F0AE)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo: ${_currencyFormat.format(casa.saldoPendiente)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Pagado: ${(progreso * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Registrar Abono / Pago de Cuota', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _mostrarDialogoAbono(casa),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeudaGeneralCard(Deuda deuda) {
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
              Text('Cuota: ${_currencyFormat.format(deuda.cuotaMensual)}${deuda.diaPago != null ? ' (Día ${deuda.diaPago})' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF43A047)),
              tooltip: 'Abonar',
              onPressed: () => _mostrarDialogoAbono(deuda),
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'eliminar') _eliminarDeuda(deuda);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
