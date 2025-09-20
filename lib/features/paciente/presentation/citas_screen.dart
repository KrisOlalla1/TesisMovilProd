import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitoreo_movil/features/auth/providers.dart';
import '../../notificaciones/data/notif_remote.dart';
import '../../paciente/domain/entities.dart';

final citasListaProvider = FutureProvider<List<Cita>>((ref) async {
  final dio = ref.read(dioProvider);
  final notif = NotifRemote(dio);
  final todas = await notif.misNotificaciones();
  if (todas.isNotEmpty) return todas;
  return notif.proximas();
});

class CitasScreen extends ConsumerWidget {
  const CitasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(citasListaProvider);
    return data.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('No tienes citas registradas.'))
          : ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = list[i];
          return ListTile(
            leading: CircleAvatar(
              child: Icon(c.leida ? Icons.event_available : Icons.event),
            ),
            title: Text(c.titulo.isEmpty ? 'Cita' : c.titulo),
            subtitle: Text('${c.mensaje}\n${c.fechaCita} • ${c.estado}'),
            isThreeLine: true,
            trailing: c.leida ? const Icon(Icons.check, color: Colors.green) : null,
          );
        },
      ),
      error: (_, __) => const Center(child: Text('No se pudieron cargar tus citas.')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
