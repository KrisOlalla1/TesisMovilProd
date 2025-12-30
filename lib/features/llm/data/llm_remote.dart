import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  /// forceOllama: Si true, salta respuestas predeterminadas y llama a Ollama directamente
  Future<String> recomendacion(
      String prompt, {
        String tipo = 'general',
        bool fast = true,
        bool forceOllama = false, // Solo forzar cuando hay signos alterados
      }) async {
    try {
      debugPrint('🔵 LLM: Enviando request a /llm/recomendacion${forceOllama ? "?forceOllama=1" : ""}');
      debugPrint('🔵 LLM: BaseURL: ${_dio.options.baseUrl}');
      
      final r = await _dio.post(
        '/llm/recomendacion',
        queryParameters: {
          if (fast) 'fast': '1',
          'tipo': tipo,
          if (forceOllama) 'forceOllama': '1', // Solo enviar si hay signos alterados
        },
        data: {'prompt': prompt},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      debugPrint('🟢 LLM: Response status: ${r.statusCode}');
      debugPrint('🟢 LLM: Response data: ${r.data}');

      final d = (r.data is Map) ? Map<String, dynamic>.from(r.data) : <String, dynamic>{};
      final timedOut = d['timed_out'] == true;
      final texto = (d['recomendacion'] as String?) ?? 'Sin respuesta del modelo';
      return timedOut
          ? '$texto\n\n(Servidor ocupado: respuesta breve. Intenta nuevamente para más detalle.)'
          : texto;
    } on DioException catch (e) {
      debugPrint('🔴 LLM DioError: ${e.type} - ${e.message}');
      debugPrint('🔴 LLM Status: ${e.response?.statusCode}');
      debugPrint('🔴 LLM Response: ${e.response?.data}');
      
      if (e.response?.statusCode == 401) {
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      }
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        return 'La IA tardó demasiado (timeout). Intenta de nuevo.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Error de conexión. Verifica tu internet.';
      }
      // Mostrar el error real del servidor si existe
      final serverError = e.response?.data;
      if (serverError is Map && serverError['error'] != null) {
        return 'Error del servidor: ${serverError['error']}';
      }
      return 'Error ${e.response?.statusCode ?? "desconocido"}: ${e.message ?? "sin detalles"}';
    } catch (e) {
      debugPrint('🔴 LLM Error general: $e');
      return 'Error inesperado: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
    }
  }
}
