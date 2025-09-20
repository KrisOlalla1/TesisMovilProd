import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitoreo_movil/features/auth/providers.dart';
import '../../paciente/data/paciente_remote.dart';
import '../../signos/data/signos_remote.dart';

final perfilProvider = FutureProvider((ref) async {
  final dio = ref.read(dioProvider);
  return PacienteRemote(dio).me();
});

class SignosScreen extends ConsumerStatefulWidget {
  const SignosScreen({super.key});
  @override
  ConsumerState<SignosScreen> createState() => _SignosScreenState();
}

class _SignosScreenState extends ConsumerState<SignosScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _enviando = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider);
    return perfil.when(
      data: (p) {
        if (p.signosHabilitados.isEmpty) {
          return const Center(
            child: Text('Tu doctor aún no habilita signos para autogestión.'),
          );
        }

        // Crea un controller por cada tipo habilitado
        for (final tipo in p.signosHabilitados) {
          _controllers.putIfAbsent(tipo, () => TextEditingController());
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Registrar signos (habilitados): ${p.signosHabilitados.join(', ')}',
              ),
              const SizedBox(height: 12),
              ...p.signosHabilitados.map((t) => TextField(
                controller: _controllers[t],
                decoration: InputDecoration(
                  labelText: t.replaceAll('_', ' '),
                  hintText: _hintFor(t),
                ),
              )),
              const SizedBox(height: 12),
              if (_msg != null)
                Text(
                  _msg!,
                  style: TextStyle(
                      color: _msg!.startsWith('Error') ? Colors.red : Colors.green),
                ),
              ElevatedButton(
                onPressed: _enviando
                    ? null
                    : () async {
                  setState(() {
                    _enviando = true;
                    _msg = null;
                  });
                  try {
                    final mapa = <String, String>{};
                    _controllers.forEach((k, v) {
                      final val = v.text.trim();
                      if (val.isNotEmpty) mapa[k] = val;
                    });
                    final dio = ref.read(dioProvider);
                    await SignosRemote(dio).crearMisSignos(mapa);
                    setState(() => _msg = 'Signos registrados correctamente');
                    _controllers.values.forEach((c) => c.clear());
                  } catch (e) {
                    setState(() => _msg =
                    'Error al registrar signos (verifica tipos/valores)');
                  } finally {
                    setState(() => _enviando = false);
                  }
                },
                child: _enviando
                    ? const CircularProgressIndicator()
                    : const Text('Guardar'),
              )
            ],
          ),
        );
      },
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  String _hintFor(String tipo) {
    switch (tipo) {
      case 'pulso':
      case 'frecuencia_cardiaca':
        return 'Ej: 72';
      case 'altura':
      case 'estatura':
        return 'Ej: 170';
      case 'temperatura':
      case 'temperatura_corporal':
        return 'Ej: 36.5';
      case 'peso':
        return 'Ej: 70';
      case 'presion_arterial':
        return 'Ej: 120/80';
      case 'glucosa':
        return 'Ej: 95';
      case 'spo2':
      case 'saturacion_oxigeno':
        return 'Ej: 98';
      case 'frecuencia_respiratoria':
        return 'Ej: 16';
      default:
        return 'Ingrese valor';
    }
  }
}
