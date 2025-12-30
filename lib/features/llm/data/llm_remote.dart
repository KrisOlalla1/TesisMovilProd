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
      
      // Extraer texto de respuesta (puede venir en varios campos)
      String texto = (d['recomendacion'] ?? d['respuesta'] ?? d['mensaje'] ?? d['text'] ?? 'Sin respuesta del modelo').toString();
      
      // Limpiar literales \n que el backend envía como texto
      texto = texto
          .replaceAll('\\n\\n', '\n\n')
          .replaceAll('\\n', '\n')
          .replaceAll('\\t', ' ')
          .replaceAll(RegExp(r'\s+'), ' ') // Múltiples espacios a uno
          .replaceAll(' \n', '\n')
          .replaceAll('\n ', '\n')
          .trim();
      
      // Si el texto tiene "Peso:", "IMC:", etc. es estadísticas, no recomendación
      // Agregar encabezado si falta
      if (!texto.contains('🩺') && !texto.startsWith('Recomendación')) {
        texto = '🩺 Recomendación médica\n$texto';
      }
      
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
  /// Formatea respuesta JSON en texto legible. Si es texto normal, lo devuelve tal cual.
  String _formatearRespuesta(String texto) {
    // Si el texto NO contiene JSON (no tiene llaves), devolverlo sin modificar
    final startIndex = texto.indexOf('{');
    final endIndex = texto.lastIndexOf('}');
    
    // No hay JSON válido -> devolver texto original
    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      return texto;
    }

    // Intentar parsear el JSON encontrado
    try {
      final jsonString = texto.substring(startIndex, endIndex + 1);
      final json = jsonDecode(jsonString);
      
      if (json is! Map || json.isEmpty) {
        return texto; // JSON vacío o no es objeto -> devolver original
      }

      // Parseo exitoso -> formatear bonito
      return _construirTextoDesdeMapa(Map<String, dynamic>.from(json));
    } catch (e) {
      debugPrint('⚠️ Error parseando JSON: $e');
      // Error en parseo -> devolver texto original (puede ser texto normal mezclado con basura)
      // Pero si el texto empieza bien (con emoji), cortar la basura JSON
      if (texto.trim().startsWith('🩺') && startIndex > 50) {
        return texto.substring(0, startIndex).trim();
      }
      return texto;
    }
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
      final keysManejadas = <String>{}; // Para rastrear qué ya mostramos

      // 1. Título
      var titulo = json['título'] ?? json['titulo'] ?? json['title'] ?? 'Recomendación médica';
      // Limpiar titulo si viene con emoji repetido
      titulo = titulo.toString().replaceAll('🩺', '').trim();
      buffer.writeln('🩺 $titulo');
      keysManejadas.addAll(['título', 'titulo', 'title']);

      // 2. Prioridad
      var prioridad = json['prioridad'] ?? json['priority'] ?? json['nivel'] ?? 'MEDIA';
      keysManejadas.addAll(['prioridad', 'priority', 'nivel']);
      
      String pTexto = prioridad.toString().toUpperCase().replaceAll('🔴', '').replaceAll('🟠', '').replaceAll('🟢', '').trim();
      if (pTexto.isEmpty) pTexto = 'MEDIA'; // Default si solo venía emoji

      String icono = '🟠'; // Default MEDIA
      if (pTexto.contains('ALTA') || pTexto.contains('RED') || pTexto.contains('URGENTE') || prioridad.toString().contains('🔴')) {
        icono = '🔴';
        if (pTexto == 'MEDIA') pTexto = 'ALTA'; // Corregir si detectamos rojo pero texto era default
      } else if (pTexto.contains('BAJA') || pTexto.contains('VERDE') || prioridad.toString().contains('🟢')) {
        icono = '🟢';
        if (pTexto == 'MEDIA') pTexto = 'BAJA';
      }
      
      buffer.writeln('Prioridad: $icono $pTexto');

      // 3. Periodo
      final periodo = json['periodo'] ?? json['rango'] ?? json['period'];
      if (periodo != null) {
        buffer.writeln('Periodo evaluado: $periodo');
        keysManejadas.addAll(['periodo', 'rango', 'period']);
      }

      // 4. Parámetros a corregir (Anomalías)
      final anomaliasKey = ['parámetros_a_corregir', 'parametros_a_corregir', 'anomalías', 'anomalias', 'abnormalities', 'signos_alterados']
          .firstWhere((k) => json.containsKey(k), orElse: () => '');
      
      if (anomaliasKey.isNotEmpty) {
        keysManejadas.add(anomaliasKey);
        final anomalias = json[anomaliasKey];
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

      // 5. Acciones inmediatas / Recomendaciones
      final accionesKey = ['acciones_inmediatas', 'acciones', 'recomendaciones', 'recommendations', 'pasos', 'tratamiento', 'consejos']
          .firstWhere((k) => json.containsKey(k), orElse: () => '');

      if (accionesKey.isNotEmpty) {
        keysManejadas.add(accionesKey);
        final acciones = json[accionesKey];
        if (acciones is List && acciones.isNotEmpty) {
          buffer.writeln('\n📋 Acciones inmediatas:');
          for (var item in acciones) {
            buffer.writeln('• $item');
          }
        } else if (acciones is String) {
          buffer.writeln('\n📋 Acciones inmediatas:\n$acciones');
        }
      }

      // 6. Siguientes pasos
      final siguientesPasosKey = ['siguientes_pasos', 'next_steps', 'seguimiento']
          .firstWhere((k) => json.containsKey(k), orElse: () => '');
          
      if (siguientesPasosKey.isNotEmpty) {
        keysManejadas.add(siguientesPasosKey);
        final siguientesPasos = json[siguientesPasosKey];
        buffer.writeln('\nSiguientes pasos: $siguientesPasos');
      }

      // 7. Seguridad / Alertas
      final seguridadKey = ['seguridad_del_paciente', 'seguridad', 'señales_alarma', 'alertas', 'warnings']
          .firstWhere((k) => json.containsKey(k), orElse: () => '');

      if (seguridadKey.isNotEmpty) {
        keysManejadas.add(seguridadKey);
        final seguridad = json[seguridadKey];
        if (seguridad is List && seguridad.isNotEmpty) {
           buffer.writeln('\n🚨 Seguridad del paciente:');
           for (var item in seguridad) buffer.writeln('• $item');
        } else {
           buffer.writeln('\n🚨 Seguridad del paciente: $seguridad');
        }
      }
      
      // 8. Mensaje / Resumen (si existe)
      final mensajeKey = ['mensaje', 'message', 'resumen', 'summary']
          .firstWhere((k) => json.containsKey(k), orElse: () => '');
      if (mensajeKey.isNotEmpty) {
         keysManejadas.add(mensajeKey);
         if (buffer.length < 100) { // Solo si falta info
            buffer.writeln('\n${json[mensajeKey]}');
         }
      }

      // 9. FALLBACK GENÉRICO: Si el buffer es muy corto, imprimir keys restantes no manejadas
      // Esto es crucial para debugging visual si la IA inventa keys nuevas
      if (buffer.length < 150) {
        json.forEach((k, v) {
          if (!keysManejadas.contains(k)) {
             if (v is List && v.isNotEmpty) {
               buffer.writeln('\n📝 $k:'); // Mostrar key como título
               for (var i in v) buffer.writeln('• $i');
             } else if (v is String && v.length > 5) {
               buffer.writeln('\n📝 $k: $v');
             } else if (v is Map && v.isNotEmpty) {
               buffer.writeln('\n📝 $k:');
               v.forEach((mk, mv) => buffer.writeln('• $mk: $mv'));
             }
          }
        });
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
