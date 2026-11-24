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
  String? _pinGuardado;
  String? _primerPinCreacion;
  bool _modoCreacion = false;
  bool _confirmandoPin = false;
  String _mensaje = 'Ingresa tu PIN';
  bool _error = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarPinExistente();
  }

  Future<void> _verificarPinExistente() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('pin_seguridad');

    setState(() {
      _pinGuardado = pin;
      _cargando = false;

      if (widget.cambiarPin || pin == null || pin.isEmpty) {
        _modoCreacion = true;
        _mensaje = 'Crea tu PIN de 4 dígitos';
      } else {
        _modoCreacion = false;
        _mensaje = 'Ingresa tu PIN de seguridad';
      }
    });
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
    final prefs = await SharedPreferences.getInstance();

    if (_modoCreacion) {
      if (!_confirmandoPin) {
        // Primer paso de creación
        setState(() {
          _primerPinCreacion = _pinIngresado;
          _pinIngresado = '';
          _confirmandoPin = true;
          _mensaje = 'Confirma tu PIN (ingrésalo de nuevo)';
        });
      } else {
        // Segundo paso: confirmar
        if (_pinIngresado == _primerPinCreacion) {
          await prefs.setString('pin_seguridad', _pinIngresado);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.green,
                content: Text('¡PIN configurado correctamente!'),
              ),
            );
            _irAHome();
          }
        } else {
          setState(() {
            _error = true;
            _pinIngresado = '';
            _confirmandoPin = false;
            _mensaje = 'Los PIN no coinciden. Intenta crear uno nuevo.';
          });
        }
      }
    } else {
      // Verificación normal de PIN
      if (_pinIngresado == _pinGuardado) {
        _irAHome();
      } else {
        setState(() {
          _error = true;
          _pinIngresado = '';
          _mensaje = 'PIN incorrecto. Intenta de nuevo.';
        });
      }
    }
  }

  void _irAHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                  // Icono de candado / casa
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                    child: const Icon(Icons.lock_person, size: 42, color: Color(0xFF1E88E5)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mis Cuentas Casa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mensaje,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _error ? Colors.red.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),

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
                              : (estaLleno ? const Color(0xFF1E88E5) : Colors.grey.shade300),
                          border: Border.all(
                            color: _error
                                ? Colors.red
                                : (estaLleno ? const Color(0xFF1E88E5) : Colors.grey.shade400),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 48),

                  // Teclado Numérico
                  _buildTecladoNumerico(),
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
          ['', '0', 'DEL']
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: fila.map((item) {
                if (item.isEmpty) {
                  return const SizedBox(width: 72, height: 72);
                }
                if (item == 'DEL') {
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined, size: 28, color: Colors.black54),
                      onPressed: _onBorrar,
                    ),
                  );
                }
                return SizedBox(
                  width: 72,
                  height: 72,
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
