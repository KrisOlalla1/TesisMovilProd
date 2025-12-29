import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart'; // Shared providers

class CitasScreen extends ConsumerWidget {
  const CitasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(citasAllProvider);
    return data.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('No tienes citas registradas.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final c = list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.leida ? Colors.grey.shade100 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: c.leida ? Colors.grey : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.titulo.isEmpty ? 'Consulta Médica' : c.titulo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${c.fechaCita.day}/${c.fechaCita.month}/${c.fechaCita.year} • ${c.fechaCita.hour}:${c.fechaCita.minute.toString().padLeft(2,'0')}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (c.leida) const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                  if (c.mensaje.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(c.mensaje, style: const TextStyle(color: Colors.black87)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.estado == 'pendiente' ? Colors.orange.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.estado.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c.estado == 'pendiente' ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
      error: (_, __) => const Center(child: Text('No se pudieron cargar tus citas.')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
