import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:monitoreo_movil/features/auth/providers.dart';
import 'providers.dart'; // Import shared providers
import '../../notificaciones/data/notif_remote.dart';
import '../../signos/data/signos_remote.dart';
import '../../paciente/domain/entities.dart';
import '../../../core/notification_service.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});
  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  CalendarFormat _format = CalendarFormat.twoWeeks; // Default to 2 weeks for bigger cells

  @override
  void initState() {
    super.initState();
    _programarNotificaciones();
  }

  Future<void> _programarNotificaciones() async {
    // 1. Recordatorios de Citas
    final citas = await ref.read(citasAllProvider.future);
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

    // 2. Recordatorios Diarios de Signos Vitales (8:00 AM y 8:00 PM)
    await NotiService.scheduleDaily(1001, title: 'Registro de Signos', body: 'No olvides registrar tus signos vitales de la mañana.', hour: 8, minute: 0);
    await NotiService.scheduleDaily(1002, title: 'Registro de Signos', body: 'Recuerda registrar tus signos vitales de la noche.', hour: 20, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final citasAsync  = ref.watch(citasAllProvider);
    final signosAsync = ref.watch(signosProvider);
    final countAsync  = ref.watch(citasCountProvider);

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
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendario',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Text('Tus eventos y registros', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              _Bell(countAsync: countAsync, onTap: () => _showProximas(context, citas)),
            ],
          ),
        ),

        // Calendario
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            children: [
              TableCalendar<String>(
                firstDay: DateTime.utc(2020,1,1),
                lastDay: DateTime.utc(2035,12,31),
                focusedDay: _focused,
                calendarFormat: _format,
                onFormatChanged: (format) => setState(() => _format = format),
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
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true, 
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                rowHeight: 60, // Taller rows for easier tapping
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  defaultTextStyle: const TextStyle(fontSize: 16),
                  weekendTextStyle: const TextStyle(fontSize: 16, color: Colors.red),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  markerSize: 8,
                ),
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
                            Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.orange)),
                          if (signosCount > 0)
                            Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.green)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: Colors.orange, label: 'Cita'),
                    SizedBox(width: 16),
                    _LegendDot(color: Colors.green, label: 'Signos'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Detalle del día
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                if (citasSel.isEmpty && signosSel.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('Sin eventos para el ${_selected.day}/${_selected.month}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                if (citasSel.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Citas Programadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ...citasSel.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.event, color: Colors.orange),
                      ),
                      title: Text(c.titulo.isEmpty ? 'Cita Médica' : c.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${c.mensaje}\n${c.fechaCita.hour}:${c.fechaCita.minute.toString().padLeft(2,'0')} • ${c.estado}'),
                      isThreeLine: true,
                      trailing: c.leida ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    ),
                  )),
                ],

                if (signosSel.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Registros de Salud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ...signosSel.map((s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.monitor_heart, color: Colors.green),
                      ),
                      title: Text(s.tipo.isEmpty ? 'Signo Vital' : s.tipo.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${s.valor}\n${s.fecha.hour}:${s.fecha.minute.toString().padLeft(2,'0')}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _editarSigno(context, s),
                      ),
                    ),
                  )),
                ],
              ],
            ),
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
    ref.invalidate(signosProvider);
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


