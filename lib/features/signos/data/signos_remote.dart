import 'package:dio/dio.dart';
import '../../paciente/domain/entities.dart';

class SignosRemote {
  final Dio _dio;
  SignosRemote(this._dio);

  Future<void> crearMisSignos(Map<String, String> signos) async {
    final r = await _dio.post('/signos-vitales/me', data: {'signos': signos});
    if (r.statusCode == 401 || r.statusCode == 403) return;
  }

  Future<List<Signo>> listarMisSignos() async {
    final r = await _dio.get('/signos-vitales/me');
    if (r.statusCode == 401 || r.statusCode == 403) return <Signo>[];
    return _parseListado(r.data);
  }

  /// Editar un signo. Si tu backend no tiene PATCH, hago fallback a crear otro registro.
  Future<void> editarSigno(Signo signo) async {
    if (signo.id.isNotEmpty) {
      final res = await _dio.patch('/signos-vitales/me/${signo.id}', data: signo.toBody());
      if (res.statusCode == 200) return;
      // si 404/405/403, intento fallback:
    }
    await crearMisSignos({signo.tipo: signo.valor});
  }

  List<Signo> _parseListado(dynamic body) {
    List list;
    if (body is List) {
      list = body;
    } else if (body is Map<String, dynamic>) {
      final dynamic maybe =
          body['data'] ??
              body['items'] ??
              body['signos'] ??
              body['results'] ??
              body['rows'];
      list = (maybe is List) ? maybe : const [];
    } else {
      list = const [];
    }
    return list.cast<Map<String, dynamic>>().map(Signo.fromJson).toList();
  }
}
