import 'package:dio/dio.dart';
import '../../paciente/domain/entities.dart';

class NotifRemote {
  final Dio _dio;
  NotifRemote(this._dio);

  Future<List<Cita>> misNotificaciones() async {
    final r = await _dio.get('/notificaciones/me');
    if (r.statusCode == 401 || r.statusCode == 403) return <Cita>[];
    return _parseListado(r.data);
  }

  Future<List<Cita>> proximas() async {
    final r = await _dio.get('/notificaciones/me/proximas');
    if (r.statusCode == 401 || r.statusCode == 403) return <Cita>[];
    return _parseListado(r.data);
  }

  Future<void> marcarLeida(String id) async {
    final r = await _dio.patch('/notificaciones/me/$id/leida');
    if (r.statusCode == 401 || r.statusCode == 403) return;
  }

  List<Cita> _parseListado(dynamic body) {
    List list;
    if (body is List) {
      list = body;
    } else if (body is Map<String, dynamic>) {
      final dynamic maybe =
          body['data'] ??
              body['items'] ??
              body['notificaciones'] ??
              body['results'] ??
              body['rows'];
      list = (maybe is List) ? maybe : const [];
    } else {
      list = const [];
    }
    return list.cast<Map<String, dynamic>>().map(Cita.fromJson).toList();
  }
}
