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
  
  /// Formatea respuesta JSON en texto legible y bonito
  String _formatearRespuesta(String texto) {
    Map<String, dynamic>? json;

    // 1. Intentar encontrar y parsear JSON formal
    try {
      String jsonString = texto;
      final startIndex = texto.indexOf('{');
      final endIndex = texto.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonString = texto.substring(startIndex, endIndex + 1);
        json = jsonDecode(jsonString);
      } else if (texto.trim().startsWith('{')) {
        json = jsonDecode(texto);
      }
    } catch (_) {
      // Ignorar error de parseo por ahora, intentaremos fallback
    }

    // 2. Fallback: Parseo manual robusto si jsonDecode falló o no encontró JSON
    // Buscamos patrones clave incluso si el JSON está roto
    if (json == null || json is! Map) {
      final tieneLlaves = texto.contains('{') || texto.contains('}');
      // Si parece JSON (tiene llaves) o tiene claves conocidas, intentamos extraer datos a la fuerza
      if (tieneLlaves || texto.contains('"prioridad"') || texto.contains('Prioridad:')) {
         json = _extraerDatosManualmente(texto);
      }
    }

    // 3. Si logramos obtener un mapa de datos (sea por decode o fallback), formateamos
    if (json != null && json is Map && json.isNotEmpty) {
      return _construirTextoDesdeMapa(Map<String, dynamic>.from(json));
    }

    // 4. Si todo falla, devolvemos el texto original limpiando posible basura JSON al final
    // solo si estamos seguros de que el texto original tiene contenido valioso al principio
    if (texto.trim().startsWith('🩺')) {
        final cut = texto.indexOf('{');
        if (cut > 50) { // Solo cortar si hay al menos 50 caracteres de texto antes del JSON
           return texto.substring(0, cut).trim(); 
        }
    }

    return texto;
  }

  /// Intenta extraer campos clave usando Regex cuando el JSON está malformado
  Map<String, dynamic> _extraerDatosManualmente(String texto) {
    final datos = <String, dynamic>{};
    
    // Prioridad
    final matchPrio = RegExp(r'"prioridad":\s*"([^"]+)"', caseSensitive: false).firstMatch(texto);
    if (matchPrio != null) datos['prioridad'] = matchPrio.group(1);

    // Periodo
    final matchPeriodo = RegExp(r'"periodo":\s*"([^"]+)"', caseSensitive: false).firstMatch(texto);
    if (matchPeriodo != null) datos['periodo'] = matchPeriodo.group(1);
    
    // Título
    final matchTitulo = RegExp(r'"título":\s*"([^"]+)"', caseSensitive: false).firstMatch(texto);
    if (matchTitulo != null) datos['título'] = matchTitulo.group(1);

    // Anomalías (simple extracción de valores si existen)
    // Esto es limitado, pero mejor que nada. Buscamos bloques de objetos en arrays
    if (texto.contains('parámetros_a_corregir') || texto.contains('anomalías')) {
       // Intentar capturar algo simple... es difícil con regex anidados.
       // Asumimos que si llegamos aquí, mejor devolveremos los campos planos que encontramos
       datos['mensaje'] = "No se pudo formatear el detalle completo, pero se detectaron datos.";
    }
    
    return datos;
  }

  String _construirTextoDesdeMapa(Map<String, dynamic> json) {
      final buffer = StringBuffer();

      // 1. Título y Prioridad
      final titulo = json['título'] ?? json['titulo'] ?? json['title'] ?? 'Recomendación médica';
      buffer.writeln('🩺 $titulo');

      final prioridad = json['prioridad'] ?? json['priority'] ?? json['nivel'] ?? 'MEDIA';
      String iconoPrioridad = '🟠';
      final pUpper = prioridad.toString().toUpperCase();
      if (pUpper.contains('ALTA') || pUpper.contains('RED') || pUpper.contains('URGENTE')) iconoPrioridad = '🔴';
      if (pUpper.contains('BAJA') || pUpper.contains('VERDE')) iconoPrioridad = '🟢';
      
      buffer.writeln('Prioridad: $iconoPrioridad $pUpper');

      // 2. Periodo
      final periodo = json['periodo'] ?? json['rango'] ?? json['period'];
      if (periodo != null) {
        buffer.writeln('Periodo evaluado: $periodo');
      }

      // 3. Parámetros a corregir (Anomalías)
      final anomalias = json['parámetros_a_corregir'] ?? 
                        json['parametros_a_corregir'] ?? 
                        json['anomalías'] ?? 
                        json['anomalias'] ?? 
                        json['abnormalities'] ??
                        json['signos_alterados'];

      if (anomalias != null) {
        if (anomalias is List && anomalias.isNotEmpty) {
           buffer.writeln('\n⚠️ Parámetros a corregir:');
           for (var item in anomalias) {
             if (item is Map) {
               final signo = item['signo'] ?? item['nombre'] ?? 'Signo';
               final valor = item['valor'] ?? '';
               final problema = item['problema'] ?? item['detalle'] ?? '';
               buffer.writeln('• $signo: $valor ${problema.isNotEmpty ? "— $problema" : ""}');
             } else {
               buffer.writeln('• $item');
             }
           }
        } else if (anomalias is Map && anomalias.isNotEmpty) {
           buffer.writeln('\n⚠️ Parámetros a corregir:');
           anomalias.forEach((key, value) {
             final nombre = _nombreLegible(key.toString());
             buffer.writeln('• $nombre: $value');
           });
        }
      }

      // 4. Acciones inmediatas / Recomendaciones
      final acciones = json['acciones_inmediatas'] ?? 
                       json['acciones'] ?? 
                       json['recomendaciones'] ?? 
                       json['recommendations'] ??
                       json['pasos'];
                       
      if (acciones != null) {
        if (acciones is List && acciones.isNotEmpty) {
          buffer.writeln('\n📋 Acciones inmediatas:');
          for (var item in acciones) {
            buffer.writeln('• $item');
          }
        } else if (acciones is String) {
          buffer.writeln('\n📋 Acciones inmediatas:\n$acciones');
        }
      }

      // 5. Siguientes pasos
      final siguientesPasos = json['siguientes_pasos'] ?? json['next_steps'] ?? json['seguimiento'];
      if (siguientesPasos != null) {
        buffer.writeln('\nSiguientes pasos: $siguientesPasos');
      }

      // 6. Seguridad / Alertas
      final seguridad = json['seguridad_del_paciente'] ?? 
                        json['seguridad'] ?? 
                        json['señales_alarma'] ?? 
                        json['alertas'] ??
                        json['warnings'];
                        
      if (seguridad != null) {
        if (seguridad is List && seguridad.isNotEmpty) {
           buffer.writeln('\n🚨 Seguridad del paciente:');
           for (var item in seguridad) buffer.writeln('• $item');
        } else {
           buffer.writeln('\n🚨 Seguridad del paciente: $seguridad');
        }
      }
      
      // Si el buffer quedó muy vacío (ej. solo título), intenta devolver 'mensaje' plano
      if (buffer.length < 50 && json.containsKey('mensaje')) {
        return '$buffer\n\n${json['mensaje']}';
      }

      return buffer.toString().trim();
  }

  String _nombreLegible(String key) {
    final k = key.toLowerCase();
    if (k.contains('presion')) return 'Presión arterial';
    if (k.contains('cardiaca') || k.contains('cardíaca')) return 'Frecuencia cardíaca';
    if (k.contains('temperatura')) return 'Temperatura';
    if (k.contains('saturacion') || k.contains('oxigen')) return 'Saturación O₂';
    if (k.contains('respiratoria')) return 'Frec. respiratoria';
    if (k.contains('glucosa')) return 'Glucosa';
    if (k.contains('peso')) return 'Peso';
    return key.replaceAll('_', ' ');
  }
}
