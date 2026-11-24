import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deuda.dart';
import 'casa_detalle_screen.dart';
import 'deudas_personales_screen.dart';
import 'gastos_casa_screen.dart';
import 'pin_screen.dart';

class HomeScreen extends StatefulWidget {
  final String usuario; // 'angie' o 'esposo'

  const HomeScreen({super.key, this.usuario = 'angie'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$ ', decimalDigits: 0);
  bool _isLoading = true;

  // Datos resumen de la Casa
  final double _totalCasa = 175000000;
  double _pagadoCasa = 0;
  int _cuotasPagadas = 0;
  int _totalCuotas = 67;
  String _casaId = '';

  // Datos resumen de Gastos del Hogar
  double _totalGastosHogar = 0;
  int _cantidadGastos = 0;

  // Datos resumen de Deudas Personales (¡Solo Angie!)
  double _totalDeudasPersonales = 0;
  double _cuotasDeudasPersonales = 0;
  int _cantidadDeudasPersonales = 0;

  bool get _esAngie => widget.usuario.toLowerCase() != 'esposo';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _isLoading = true);

    try {
      // 1. Cargar datos exclusivos de la Casa desde plan_casa
      final planResp = await Supabase.instance.client
          .from('plan_casa')
          .select()
          .order('orden', ascending: true);

      if ((planResp as List).isNotEmpty) {
        double pagado = 0;
        int pagadasCount = 0;
        for (var c in planResp) {
          final isPagado = c['pagado'] == true;
          final mProg = (c['monto_programado'] as num?)?.toDouble() ?? 0.0;
          final mPag = (c['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          if (isPagado) {
            pagadasCount++;
            pagado += (mPag > 0 ? mPag : mProg);
          }
        }
        _pagadoCasa = pagado;
        _cuotasPagadas = pagadasCount;
        _totalCuotas = planResp.length;
        _casaId = planResp.first['deuda_id']?.toString() ?? '';
      }

      // 2. Cargar gastos del hogar (Mercado, recibos, etc.)
      try {
        final gastosResp = await Supabase.instance.client.from('gastos_casa').select();
        final listaGastos = gastosResp as List;
        _totalGastosHogar = listaGastos.fold<double>(0, (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0.0));
        _cantidadGastos = listaGastos.length;
      } catch (_) {}

      // 3. Cargar datos de Deudas Personales (SOLO si es Angie)
      if (_esAngie) {
        final deudasResp = await Supabase.instance.client
            .from('deudas')
            .select()
            .eq('es_cuota_casa', false);

        final listaPersonales = (deudasResp as List).map((d) => Deuda.fromMap(d)).toList();
        _totalDeudasPersonales = listaPersonales.fold(0, (sum, d) => sum + d.saldoPendiente);
        _cuotasDeudasPersonales = listaPersonales.fold(0, (sum, d) => sum + d.cuotaMensual);
        _cantidadDeudasPersonales = listaPersonales.length;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progresoCasa = _totalCasa > 0 ? (_pagadoCasa / _totalCasa).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _esAngie ? const Color(0xFFE3F2FD) : const Color(0xFFF3E5F5),
              child: Icon(
                _esAngie ? Icons.person : Icons.person_outline,
                size: 20,
                color: _esAngie ? const Color(0xFF1E88E5) : const Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _esAngie ? 'Hola, Angie' : 'Hola, Esposo',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            tooltip: 'Actualizar',
            onPressed: _cargarTodo,
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
                    Text('Gestionar PINs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarTodo,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                children: [
                  const Text(
                    'Panel del Hogar',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _esAngie
                        ? 'Gestiona la casa, los gastos y tus deudas personales'
                        : 'Gestiona la cuota de la casa y los gastos del hogar',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 1. TARJETA EXCLUSIVA DE LA CASA (AMBOS LA VEN)
                  // ==========================================
                  _buildCasaCard(progresoCasa),

                  const SizedBox(height: 18),

                  // ==========================================
                  // 2. TARJETA DE GASTOS DEL HOGAR (AMBOS LA VEN)
                  // ==========================================
                  _buildGastosHogarCard(),

                  // ==========================================
                  // 3. TARJETA DE DEUDAS PERSONALES (¡SOLO ANGIE!)
                  // ==========================================
                  if (_esAngie) ...[
                    const SizedBox(height: 18),
                    _buildDeudasPersonalesCard(),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildCasaCard(double progreso) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            final dummyCasa = Deuda(
              id: _casaId,
              nombre: 'Casa Propia',
              esCuotaCasa: true,
              montoTotal: _totalCasa,
              saldoPendiente: (_totalCasa - _pagadoCasa).clamp(0, double.infinity),
              cuotaMensual: 1500000,
            );
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CasaDetalleScreen(casa: dummyCasa)),
            );
            _cargarTodo();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                          child: const Icon(Icons.home_work, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuentas de la Casa',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Plan de pagos 2025 - 2030',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Valor Total Casa', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormat.format(_totalCasa),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Cancelado', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormat.format(_pagadoCasa),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF69F0AE)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF69F0AE)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_cuotasPagadas de $_totalCuotas cuotas pagadas',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '${(progreso * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Color(0xFF69F0AE), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_view, color: Color(0xFF4A148C), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ver Plan de Pagos (67 cuotas)',
                        style: TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGastosHogarCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF388E3C).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GastosCasaScreen(usuarioActual: widget.usuario)),
            );
            _cargarTodo();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                          child: const Icon(Icons.shopping_cart, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gastos del Hogar',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Mercado, recibos y servicios',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Gastado', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormat.format(_totalGastosHogar),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Registros', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            '$_cantidadGastos gastos',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF69F0AE)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, color: Color(0xFF1B5E20), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ingresar a Gastos del Hogar',
                        style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeudasPersonalesCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeudasPersonalesScreen()),
            );
            _cargarTodo();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                          child: const Icon(Icons.credit_card, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis Deudas Personales',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Solo visible para ti (Privado)',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Deudas ($_cantidadDeudasPersonales)',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormat.format(_totalDeudasPersonales),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cuotas / Mes', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            _currencyFormat.format(_cuotasDeudasPersonales),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF69F0AE)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Color(0xFF0D47A1), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ingresar a Mis Deudas Privadas',
                        style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
