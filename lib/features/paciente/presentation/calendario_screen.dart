import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:monitoreo_movil/features/auth/providers.dart';
import '../../notificaciones/data/notif_remote.dart';
import '../../signos/data/signos_remote.dart';
import '../../paciente/domain/entities.dart';
import '../../../core/notification_service.dart';

final _citasAllProvider = FutureProvider<List<Cita>>((ref) async {
  final dio = ref.read(dioProvider);
  final notif = NotifRemote(dio);
  final all = await notif.misNotificaciones();
  if (all.isNotEmpty) return all;
  return notif.proximas();
});

final _signosProvider = FutureProvider<List<Signo>>((ref) async {
  final dio = ref.read(dioProvider);
  return SignosRemote(dio).listarMisSignos();
});

final _citasCountProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(_citasAllProvider.future);
  final now = DateTime.now();
  return list.where((c) => c.fechaCita.isAfter(now)).length;
});

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});
  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _programarNotificaciones();
  }

  Future<void> _programarNotificaciones() async {
    final citas = await ref.read(_citasAllProvider.future);
    int id = 2000; final now = DateTime.now();
    for (final c in citas) {
      final d = c.fechaCita;
      for (final delta in const [Duration(hours: 24), Duration(hours: 2), Duration(minutes: 30)]) {
        final when = d.subtract(delta);
        if (when.isAfter(now)) {
          await NotiService.schedule(
            id++,
            title: 'Cita: ${c.titulo.isEmpty ? "Consulta médica" : c.titulo}',
            body: 'Se aproxima tu cita (${delta.inHours >= 1 ? '${delta.inHours}h' : '${delta.inMinutes} min'})',
            whenLocal: when,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final citasAsync  = ref.watch(_citasAllProvider);
    final signosAsync = ref.watch(_signosProvider);
    final countAsync  = ref.watch(_citasCountProvider);

    final citas  = citasAsync.value  ?? <Cita>[];
    final signos = signosAsync.value ?? <Signo>[];

    // Agrupar por día
    final citasByDay  = <DateTime, List<Cita>>{};
    for (final c in citas) {
      final k = DateTime(c.fechaCita.year, c.fechaCita.month, c.fechaCita.day);
      (citasByDay[k] ??= []).add(c);
    }
    final signosByDay = <DateTime, List<Signo>>{};
    for (final s in signos) {
      final k = DateTime(s.fecha.year, s.fecha.month, s.fecha.day);
      (signosByDay[k] ??= []).add(s);
    }

    // Detalle del día
    final selectedKey = DateTime(_selected.year, _selected.month, _selected.day);
    final citasSel  = citasByDay[selectedKey]  ?? const [];
    final signosSel = signosByDay[selectedKey] ?? const [];

    return Column(
      children: [
        // Título + campana
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text('Calendario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              _Bell(countAsync: countAsync, onTap: () => _showProximas(context, citas)),
            ],
          ),
        ),

        // Leyenda
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              _LegendDot(color: Color(0xFF1976D2), label: 'Cita'),
              SizedBox(width: 12),
              _LegendSquare(color: Color(0xFF388E3C), label: 'Signos'),
            ],
          ),
        ),

        // Calendario con marcadores
        TableCalendar<String>(
          firstDay: DateTime.utc(2020,1,1),
          lastDay: DateTime.utc(2035,12,31),
          focusedDay: _focused,
          selectedDayPredicate: (d) => isSameDay(_selected, d),
          onDaySelected: (sel, foc) => setState(() { _selected = sel; _focused = foc; }),
          eventLoader: (day) {
            final k = DateTime(day.year, day.month, day.day);
            final n1 = (citasByDay[k]  ?? const []).length;
            final n2 = (signosByDay[k] ?? const []).length;
            return [
              ...List.filled(n1, 'cita'),
              ...List.filled(n2, 'signo'),
            ];
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'es_EC',
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              final citasCount  = events.where((e) => e == 'cita').length;
              final signosCount = events.where((e) => e == 'signo').length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (citasCount > 0)
                      Container(width: 8, height: 8, decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFF1976D2))),
                    if (signosCount > 0) const SizedBox(width: 3),
                    if (signosCount > 0)
                      Container(width: 8, height: 8, decoration: BoxDecoration(
                          shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(2),
                          color: const Color(0xFF388E3C))),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(),

        // Detalle del día con edición de signos
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (citasSel.isEmpty && signosSel.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Sin eventos para este día.'),
                ),

              if (citasSel.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text('Citas', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ...citasSel.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(c.titulo.isEmpty ? 'Cita' : c.titulo),
                  subtitle: Text('${c.mensaje}\n${c.fechaCita} • ${c.estado}'),
                  isThreeLine: true,
                  trailing: c.leida ? const Icon(Icons.check) : null,
                ),
              )),

              if (signosSel.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 8),
                  child: Text('Signos registrados', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ...signosSel.map((s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart),
                  title: Text(s.tipo.isEmpty ? 'Signo' : s.tipo.replaceAll('_', ' ')),
                  subtitle: Text('${s.valor}\n${s.fecha}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editarSigno(context, s),
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editarSigno(BuildContext context, Signo s) async {
    final controller = TextEditingController(text: s.valor);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar ${s.tipo.replaceAll('_', ' ')}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo valor'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;

    final newValue = controller.text.trim();
    if (newValue.isEmpty) return;

    final dio = ref.read(dioProvider);
    final remote = SignosRemote(dio);
    await remote.editarSigno(Signo(id: s.id, tipo: s.tipo, valor: newValue, fecha: s.fecha));
    // refresca la lista de signos
    ref.invalidate(_signosProvider);
  }

  void _showProximas(BuildContext context, List<Cita> citas) {
    final futuras = citas.where((c) => c.fechaCita.isAfter(DateTime.now())).toList()
      ..sort((a, b) => a.fechaCita.compareTo(b.fechaCita));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Próximas citas'),
        content: SizedBox(
          width: double.maxFinite,
          child: futuras.isEmpty
              ? const Text('No tienes citas próximas.')
              : ListView.separated(
            shrinkWrap: true,
            itemCount: futuras.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (_, i) {
              final c = futuras[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.event_available),
                title: Text(c.titulo.isEmpty ? 'Cita' : c.titulo),
                subtitle: Text('${c.mensaje}\n${c.fechaCita}'),
                isThreeLine: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  final AsyncValue<int> countAsync;
  final VoidCallback onTap;
  const _Bell({required this.countAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return countAsync.when(
      data: (n) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: onTap),
          if (n > 0)
            Positioned(
              right: 6, top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
        ],
      ),
      error: (_, __) => IconButton(icon: const Icon(Icons.notifications_none), onPressed: onTap),
      loading: () => IconButton(icon: const Icon(Icons.notifications_none), onPressed: onTap),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label),
    ]);
  }
}

class _LegendSquare extends StatelessWidget {
  final Color color; final String label;
  const _LegendSquare({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label),
    ]);
  }
}
