import 'package:dio/dio.dart';

class LlmRemote {
  final Dio _dio;
  LlmRemote(this._dio);

  Future<String> estado() async {
    try {
      final r = await _dio.get('/llm/estado');
      final d = (r.data is Map) ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
      final disponible = d['lm_studio_disponible'] == true;
      if (!disponible) {
        final msg = (d['mensaje'] as String?) ?? 'No disponible';
        return 'Fuera de servicio: $msg';
      }
      final model = (d['modelo_cargado'] as String?)?.trim();
      return (model != null && model.isNotEmpty) ? 'OK ($model)' : 'OK';
    } catch (_) {
      return 'Desconocido';
    }
  }

  /// tipo: 'general' | 'preocupante' | 'vigilar' | 'habitos'
  Future<String> recomendacion(
      String prompt, {
        String tipo = 'general',
        bool fast = true,
      }) async {
    try {
      final r = await _dio.post(
        '/llm/recomendacion',
        queryParameters: {
          if (fast) 'fast': '1',
          'tipo': tipo,
        },
        data: {'prompt': prompt},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final d = (r.data is Map) ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
      final timedOut = d['timed_out'] == true;
      final texto = (d['recomendacion'] as String?) ?? 'Sin respuesta del modelo';
      return timedOut
          ? '$texto\n\n(Servidor ocupado: respuesta breve. Intenta nuevamente para más detalle.)'
          : texto;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      }
      return 'No se pudo obtener una recomendación en este momento.';
    } catch (_) {
      return 'No se pudo obtener una recomendación en este momento.';
    }
  }
}