import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitoreo_movil/features/auth/providers.dart';
import 'providers.dart'; // Import shared providers
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Nuevo Registro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ...p.signosHabilitados.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _controllers[t],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.replaceAll('_', ' ').toUpperCase(),
                            hintText: _hintFor(t),
                            prefixIcon: Icon(_iconFor(t)),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      )),
                      const SizedBox(height: 12),
                      if (_msg != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _msg!.startsWith('Error') ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _msg!.startsWith('Error') ? Icons.error_outline : Icons.check_circle_outline,
                                color: _msg!.startsWith('Error') ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _msg!,
                                  style: TextStyle(
                                      color: _msg!.startsWith('Error') ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
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
                              // Invalidate shared provider to refresh Calendar
                              ref.invalidate(signosProvider);
                              setState(() => _msg = 'Signos registrados correctamente');
                              _controllers.values.forEach((c) => c.clear());
                            } catch (e) {
                              setState(() => _msg =
                              'Error al registrar signos (verifica tipos/valores)');
                            } finally {
                              setState(() => _enviando = false);
                            }
                          },
                          icon: _enviando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: const Text('GUARDAR REGISTRO'),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.monitor_heart, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registra tus signos vitales para que tu médico pueda monitorear tu salud.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  IconData _iconFor(String tipo) {
    switch (tipo) {
      case 'pulso': return Icons.favorite;
      case 'temperatura': return Icons.thermostat;
      case 'peso': return Icons.monitor_weight;
      case 'presion_arterial': return Icons.speed;
      case 'glucosa': return Icons.water_drop;
      case 'spo2': return Icons.air;
      default: return Icons.monitor_heart;
    }
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
