import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monitoreo_movil/features/auth/providers.dart';
import '../../notificaciones/data/notif_remote.dart';
import '../../signos/data/signos_remote.dart';
import '../../paciente/domain/entities.dart';

final citasAllProvider = FutureProvider<List<Cita>>((ref) async {
  final dio = ref.read(dioProvider);
  final notif = NotifRemote(dio);
  final all = await notif.misNotificaciones();
  if (all.isNotEmpty) return all;
  return notif.proximas();
});

final signosProvider = FutureProvider<List<Signo>>((ref) async {
  final dio = ref.read(dioProvider);
  return SignosRemote(dio).listarMisSignos();
});

final citasCountProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(citasAllProvider.future);
  final now = DateTime.now();
  return list.where((c) => c.fechaCita.isAfter(now)).length;
});
