import 'package:dio/dio.dart';

class LlmRemote {
  final Dio _dio;
  LlmRemote(this._dio);

  Future<String> estado() async {
    final r = await _dio.get('/llm/estado');
    if ((r.statusCode ?? 500) >= 400) return 'Desconocido';
    return (r.data?['estado']?.toString() ??
        r.data?['status']?.toString() ??
        'OK');
  }

  /// Envía el prompt al backend. Requiere JWT (ya lo agrega el interceptor).
  Future<String> recomendacion(String prompt) async {
    final r = await _dio.post(
      '/llm/recomendacion',
      data: {'prompt': prompt},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    if ((r.statusCode ?? 500) >= 400) {
      return 'No se pudo obtener una recomendación en este momento.';
    }
    return (r.data?['recomendacion'] as String?) ??
        'Sin respuesta del modelo';
  }
}
