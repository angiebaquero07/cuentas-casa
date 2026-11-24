import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class PinScreen extends StatefulWidget {
  final bool cambiarPin;

  const PinScreen({super.key, this.cambiarPin = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pinIngresado = '';
  String? _pinAngie;
  String? _pinEsposo;
  String _mensaje = 'Ingresa tu PIN de 4 dígitos';
  bool _error = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPins();
  }

  Future<void> _cargarPins() async {
    final prefs = await SharedPreferences.getInstance();

    // Migración o carga de PINs
    var pinAngie = prefs.getString('pin_angie');
    if (pinAngie == null || pinAngie.isEmpty) {
      pinAngie = prefs.getString('pin_seguridad'); // Si ya tenía un PIN creado
      if (pinAngie != null && pinAngie.isNotEmpty) {
        await prefs.setString('pin_angie', pinAngie);
      }
    }

    var pinEsposo = prefs.getString('pin_esposo');

    setState(() {
      _pinAngie = pinAngie;
      _pinEsposo = pinEsposo;
      _cargando = false;
    });

    if (widget.cambiarPin || _pinAngie == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarDialogoConfiguracionPins();
      });
    }
  }

  void _onNumeroPresionado(String numero) {
    if (_pinIngresado.length < 4) {
      setState(() {
        _error = false;
        _pinIngresado += numero;
      });

      if (_pinIngresado.length == 4) {
        _procesarPin();
      }
    }
  }

  void _onBorrar() {
    if (_pinIngresado.isNotEmpty) {
      setState(() {
        _error = false;
        _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
      });
    }
  }

  Future<void> _procesarPin() async {
    // Si aún no hay PIN configurado
    if (_pinAngie == null || _pinAngie!.isEmpty) {
      _mostrarDialogoConfiguracionPins();
      return;
    }

    if (_pinIngresado == _pinAngie) {
      // Ingreso como Angie
      _irAHome(usuario: 'esposa');
    } else if (_pinEsposo != null && _pinIngresado == _pinEsposo) {
      // Ingreso como yeferson
      _irAHome(usuario: 'esposo');
    } else {
      setState(() {
        _error = true;
        _pinIngresado = '';
        _mensaje = 'PIN incorrecto. Intenta de nuevo.';
      });
    }
  }

  void _irAHome({required String usuario}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(usuario: usuario)),
    );
  }

  void _mostrarDialogoConfiguracionPins() {
    final angieCtrl = TextEditingController(text: _pinAngie ?? '');
    final esposoCtrl = TextEditingController(text: _pinEsposo ?? '');

    showDialog(
      context: context,
      barrierDismissible: _pinAngie != null,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF1E88E5)),
            SizedBox(width: 8),
            Text(
              'Configurar PINs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cada uno tendrá su propio PIN para entrar desde el celular:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // PIN de Angie
              TextField(
                controller: angieCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'PIN de Angie (Acceso a Todo)',
                  helperText: 'Ve Casa, Gastos y sus Deudas privadas',
                  prefixIcon: Icon(Icons.person, color: Color(0xFF1E88E5)),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // PIN del Esposo
              TextField(
                controller: esposoCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'PIN del Esposo',
                  helperText: 'Solo ve Casa y Gastos (NO ve tus deudas)',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Color(0xFF4A148C),
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_pinAngie != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
            ),
            onPressed: () async {
              final pAngie = angieCtrl.text.trim();
              final pEsposo = esposoCtrl.text.trim();

              if (pAngie.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El PIN de Angie debe tener 4 números'),
                  ),
                );
                return;
              }

              if (pEsposo.isNotEmpty) {
                if (pEsposo.length != 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El PIN del esposo debe tener 4 números'),
                    ),
                  );
                  return;
                }
                if (pEsposo == pAngie) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Los dos PIN deben ser diferentes'),
                    ),
                  );
                  return;
                }
              }

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pin_angie', pAngie);
              await prefs.setString('pin_seguridad', pAngie);
              if (pEsposo.isNotEmpty) {
                await prefs.setString('pin_esposo', pEsposo);
              }

              setState(() {
                _pinAngie = pAngie;
                _pinEsposo = pEsposo.isNotEmpty ? pEsposo : null;
                _pinIngresado = '';
                _error = false;
                _mensaje = '¡PINs configurados! Digita tu PIN para entrar.';
              });

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar PINs'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Cuentas del Hogar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mensaje,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _error
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 4 Puntos indicadores del PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final estaLleno = index < _pinIngresado.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _error
                              ? Colors.red
                              : (estaLleno
                                    ? const Color(0xFF1E88E5)
                                    : Colors.grey.shade300),
                          border: Border.all(
                            color: _error
                                ? Colors.red
                                : (estaLleno
                                      ? const Color(0xFF1E88E5)
                                      : Colors.grey.shade400),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 36),

                  // Teclado Numérico
                  _buildTecladoNumerico(),

                  const SizedBox(height: 16),

                  // Botón discreto para configurar o cambiar PINs
                  TextButton.icon(
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Gestionar PINs (Angie / Esposo)'),
                    onPressed: _mostrarDialogoConfiguracionPins,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTecladoNumerico() {
    return Column(
      children: [
        for (var fila in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'DEL'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: fila.map((item) {
                if (item.isEmpty) {
                  return const SizedBox(width: 68, height: 68);
                }
                if (item == 'DEL') {
                  return SizedBox(
                    width: 68,
                    height: 68,
                    child: IconButton(
                      icon: const Icon(
                        Icons.backspace_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      onPressed: _onBorrar,
                    ),
                  );
                }
                return SizedBox(
                  width: 68,
                  height: 68,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: const CircleBorder(),
                      shadowColor: Colors.black12,
                      side: BorderSide(color: Colors.grey.shade200, width: 1.5),
                    ),
                    onPressed: () => _onNumeroPresionado(item),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
