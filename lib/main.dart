import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa notificaciones
  await NotiService.init();
  // Inicializa datos de localización (fix para TableCalendar/intl)
  await initializeDateFormatting('es_EC', null);
  runApp(const ProviderScope(child: MonitoreoApp()));
}
