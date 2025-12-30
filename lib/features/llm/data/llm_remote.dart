import 'dart:convert';
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
      
      // Formatear la respuesta si es JSON
      final textoFormateado = _formatearRespuesta(texto);
      
      return timedOut
          ? '$textoFormateado\n\n(Servidor ocupado: respuesta breve. Intenta nuevamente para más detalle.)'
          : textoFormateado;
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
  
  /// Formatea respuesta JSON en texto legible
  String _formatearRespuesta(String texto) {
    // Si es texto normal (no JSON), devolverlo tal cual
    if (!texto.trim().startsWith('{')) {
      return texto;
    }
    
    try {
      final json = jsonDecode(texto);
      if (json is! Map) return texto;
      
      final buffer = StringBuffer();
      
      // Encabezado
      buffer.writeln('🩺 Recomendación médica');
      
      // Prioridad
      final prioridad = json['prioridad'] ?? json['priority'] ?? '';
      if (prioridad.toString().isNotEmpty) {
        buffer.writeln('Prioridad: $prioridad');
      }
      
      // Anomalías detectadas
      final anomalias = json['anomalías'] ?? json['anomalias'] ?? json['abnormalities'];
      if (anomalias != null && anomalias is Map && anomalias.isNotEmpty) {
        buffer.writeln('\n⚠️ Parámetros alterados:');
        anomalias.forEach((key, value) {
          final nombre = _nombreLegible(key.toString());
          buffer.writeln('• $nombre: $value');
        });
      }
      
      // Recomendaciones
      final recomendaciones = json['recomendaciones'] ?? json['recommendations'] ?? json['acciones'];
      if (recomendaciones != null) {
        buffer.writeln('\n📋 Recomendaciones:');
        if (recomendaciones is List) {
          for (var rec in recomendaciones) {
            buffer.writeln('• $rec');
          }
        } else {
          buffer.writeln('$recomendaciones');
        }
      }
      
      // Mensaje o resumen
      final mensaje = json['mensaje'] ?? json['message'] ?? json['resumen'];
      if (mensaje != null) {
        buffer.writeln('\n$mensaje');
      }
      
      // Alertas
      final alertas = json['alertas'] ?? json['warnings'];
      if (alertas != null) {
        buffer.writeln('\n🚨 Alertas:');
        if (alertas is List) {
          for (var alerta in alertas) {
            buffer.writeln('• $alerta');
          }
        } else {
          buffer.writeln('$alertas');
        }
      }
      
      return buffer.toString().trim();
    } catch (_) {
      // Si no es JSON válido, devolver tal cual
      return texto;
    }
  }
  
  String _nombreLegible(String key) {
    const nombres = {
      'presion_arterial': 'Presión arterial',
      'frecuencia_cardiaca': 'Frecuencia cardíaca',
      'temperatura': 'Temperatura',
      'saturacion_oxigeno': 'Saturación O₂',
      'saturación_oxigen': 'Saturación O₂',
      'glucosa': 'Glucosa',
      'peso': 'Peso',
      'frecuencia_respiratoria': 'Frec. respiratoria',
    };
    return nombres[key.toLowerCase()] ?? key.replaceAll('_', ' ');
  }
}
