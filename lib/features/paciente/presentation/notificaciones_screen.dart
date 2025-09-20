import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitoreo_movil/features/auth/providers.dart';
import '../../notificaciones/data/notif_remote.dart';
import '../../paciente/domain/entities.dart';

final notifProvider = FutureProvider<List<Cita>>((ref) async {
  final dio = ref.read(dioProvider);
  return NotifRemote(dio).proximas();
});

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notifProvider);
    return data.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('No tienes notificaciones próximas.'))
          : ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final c = list[i];
          return ListTile(
            title: Text(c.titulo),
            subtitle: Text('${c.mensaje}\n${c.fechaCita}'),
            trailing: c.leida
                ? const Icon(Icons.check)
                : TextButton(
              child: const Text('Marcar leída'),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                await NotifRemote(dio).marcarLeida(c.id);
                ref.invalidate(notifProvider);
              },
            ),
            isThreeLine: true,
          );
        },
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
