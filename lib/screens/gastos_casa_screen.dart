import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gasto_casa.dart';

class GastosCasaScreen extends StatefulWidget {
  final String usuarioActual;

  const GastosCasaScreen({super.key, required this.usuarioActual});

  @override
  State<GastosCasaScreen> createState() => _GastosCasaScreenState();
}

class _GastosCasaScreenState extends State<GastosCasaScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$ ', decimalDigits: 0);
  List<GastoCasa> _gastos = [];
  bool _isLoading = true;
  String _categoriaFiltro = 'Todas';

  final List<String> _categorias = [
    'Mercado',
    'Luz / Electricidad',
    'Agua',
    'Gas',
    'Internet / Teléfono',
    'Administración',
    'Mantenimiento',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _cargarGastos();
  }

  Future<void> _cargarGastos() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('gastos_casa')
          .select()
          .order('fecha', ascending: false);

      final lista = (response as List).map((g) => GastoCasa.fromMap(g)).toList();
      setState(() {
        _gastos = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double _parsearMonto(String texto) {
    final limpio = texto.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(limpio) ?? 0.0;
  }

  String _formatearFecha(DateTime fecha) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${fecha.day} de ${meses[fecha.month - 1]} ${fecha.year}';
  }

  double get _totalGastos => _gastos.fold<double>(0, (sum, g) => sum + g.monto);

  IconData _getIconoCategoria(String cat) {
    switch (cat) {
      case 'Mercado':
        return Icons.shopping_cart;
      case 'Luz / Electricidad':
        return Icons.lightbulb_outline;
      case 'Agua':
        return Icons.water_drop_outlined;
      case 'Gas':
        return Icons.local_fire_department_outlined;
      case 'Internet / Teléfono':
        return Icons.wifi;
      case 'Administración':
        return Icons.apartment;
      case 'Mantenimiento':
        return Icons.build_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  Color _getColorCategoria(String cat) {
    switch (cat) {
      case 'Mercado':
        return const Color(0xFF2E7D32);
      case 'Luz / Electricidad':
        return const Color(0xFFF57F17);
      case 'Agua':
        return const Color(0xFF0288D1);
      case 'Gas':
        return const Color(0xFFD84315);
      case 'Internet / Teléfono':
        return const Color(0xFF512DA8);
      case 'Administración':
        return const Color(0xFF00695C);
      case 'Mantenimiento':
        return const Color(0xFF455A64);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  Future<void> _mostrarDialogoNuevoGasto() async {
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String categoriaSeleccionada = 'Mercado';
    String pagador = widget.usuarioActual == 'esposo' ? 'Esposo' : 'Angie';
    DateTime fechaSeleccionada = DateTime.now();

    await showModalBottomSheet(
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
                    const Text(
                      'Nuevo Gasto del Hogar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Concepto (ej: Recibo Enel, Mercado Carulla)
                TextField(
                  controller: conceptoCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Concepto (ej: Recibo de la Luz, Mercado del mes)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Monto
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor del Gasto',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Selector de Categoría
                DropdownButtonFormField<String>(
                  value: categoriaSeleccionada, // ignore: deprecated_member_use
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: _categorias.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_getIconoCategoria(cat), size: 20, color: _getColorCategoria(cat)),
                          const SizedBox(width: 10),
                          Text(cat),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => categoriaSeleccionada = val);
                  },
                ),
                const SizedBox(height: 14),

                // Quién lo pagó
                DropdownButtonFormField<String>(
                  value: pagador, // ignore: deprecated_member_use
                  decoration: const InputDecoration(
                    labelText: 'Pagado por',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Angie', child: Text('Angie')),
                    DropdownMenuItem(value: 'Esposo', child: Text('Esposo')),
                    DropdownMenuItem(value: 'Ambos', child: Text('Ambos (Mitad y Mitad)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => pagador = val);
                  },
                ),
                const SizedBox(height: 14),

                // Selector de Fecha
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                  title: const Text('Fecha del gasto'),
                  subtitle: Text(_formatearFecha(fechaSeleccionada)),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () async {
                    final seleccion = await showDatePicker(
                      context: context,
                      initialDate: fechaSeleccionada,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (seleccion != null) {
                      setModalState(() => fechaSeleccionada = seleccion);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Notas
                TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas adicionales (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Gasto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () async {
                    final concepto = conceptoCtrl.text.trim();
                    if (concepto.isEmpty) return;
                    final monto = _parsearMonto(montoCtrl.text);
                    if (monto <= 0) return;

                    final nuevo = GastoCasa(
                      id: '',
                      concepto: concepto,
                      categoria: categoriaSeleccionada,
                      monto: monto,
                      fecha: fechaSeleccionada,
                      pagadoPor: pagador,
                      notas: notasCtrl.text.trim(),
                    );

                    await Supabase.instance.client.from('gastos_casa').insert(nuevo.toMap());
                    if (ctx.mounted) Navigator.pop(ctx);
                    _cargarGastos();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarGasto(GastoCasa gasto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Seguro que deseas eliminar el gasto "${gasto.concepto}"?'),
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
      await Supabase.instance.client.from('gastos_casa').delete().eq('id', gasto.id);
      _cargarGastos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastosFiltrados = _categoriaFiltro == 'Todas'
        ? _gastos
        : _gastos.where((g) => g.categoria == _categoriaFiltro).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Gastos del Hogar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarGastos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Añadir Gasto', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _mostrarDialogoNuevoGasto,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarGastos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // TARJETA DE RESUMEN DE GASTOS
                  _buildHeaderResumen(),
                  const SizedBox(height: 20),

                  // FILTRO DE CATEGORÍAS
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todas'),
                        ..._categorias.map((cat) => _buildFilterChip(cat)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Historial de Gastos y Recibos',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text('${gastosFiltrados.length} registros', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (gastosFiltrados.isEmpty)
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
                          Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.green),
                          SizedBox(height: 12),
                          Text('No hay gastos registrados en esta categoría',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Toca "+ Añadir Gasto" para agregar el primero.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...gastosFiltrados.map((gasto) => _buildGastoTile(gasto)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String cat) {
    final sel = _categoriaFiltro == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(cat),
        selected: sel,
        selectedColor: const Color(0xFF2E7D32),
        labelStyle: TextStyle(
          color: sel ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (val) {
          if (val) setState(() => _categoriaFiltro = cat);
        },
      ),
    );
  }

  Widget _buildHeaderResumen() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF388E3C).withValues(alpha: 0.35),
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
                  Icon(Icons.receipt, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Total Gastos Registrados',
                    style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_gastos.length} gastos',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currencyFormat.format(_totalGastos),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recibos, mercado, servicios y compras del hogar',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGastoTile(GastoCasa gasto) {
    final color = _getColorCategoria(gasto.categoria);
    final icono = _getIconoCategoria(gasto.categoria);

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
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icono, color: color, size: 22),
        ),
        title: Text(gasto.concepto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gasto.categoria,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pagó: ${gasto.pagadoPor}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_formatearFecha(gasto.fecha), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (gasto.notas.isNotEmpty)
              Text(gasto.notas, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currencyFormat.format(gasto.monto),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              tooltip: 'Eliminar',
              onPressed: () => _eliminarGasto(gasto),
            ),
          ],
        ),
      ),
    );
  }
}
