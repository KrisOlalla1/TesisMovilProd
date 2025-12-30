import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monitoreo_movil/features/auth/providers.dart';
import 'package:monitoreo_movil/features/llm/data/llm_remote.dart';
import 'package:monitoreo_movil/features/signos/data/signos_remote.dart';
import 'package:monitoreo_movil/features/paciente/domain/entities.dart';

const _opcionUnica = 'Revisión general';

const _tipoMap = {
  _opcionUnica: 'general',
};

enum _Ventana { d7, d15, d30 }

extension _VentanaX on _Ventana {
  int get dias {
    switch (this) {
      case _Ventana.d7:
        return 7;
      case _Ventana.d15:
        return 15;
      case _Ventana.d30:
        return 30;
    }
  }

  String get label => '$dias días';
  Duration get duration => Duration(days: dias);
}

final _misSignosProvider = FutureProvider<List<Signo>>((ref) async {
  final dio = ref.read(dioProvider);
  return SignosRemote(dio).listarMisSignos();
});

class RecomendacionScreen extends ConsumerStatefulWidget {
  const RecomendacionScreen({super.key});

  @override
  ConsumerState<RecomendacionScreen> createState() => _RecomendacionScreenState();
}

class _RecomendacionScreenState extends ConsumerState<RecomendacionScreen> {
  final _controller = ScrollController();

  _Ventana _ventana = _Ventana.d30;
  bool _enviando = false;
  bool _typing = false;

  final List<_Msg> _mensajes = [];

  @override
  void initState() {
    super.initState();
    _warmUpLlm();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _warmUpLlm() async {
    try {
      final dio = ref.read(dioProvider);
      final llm = LlmRemote(dio);
      await llm.estado();
    } catch (_) {}
  }

  Future<void> _scrollBottom() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (_controller.hasClients) {
      _controller.animateTo(
        _controller.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _enviarOpcion(String opcion) async {
    if (_enviando) return;
    setState(() => _enviando = true);

    _mensajes.add(_Msg.user(opcion));
    setState(() {});
    await _scrollBottom();

    _typing = true;
    setState(() {});
    await _scrollBottom();

    try {
      await _warmUpLlm();

      final signos = await ref.read(_misSignosProvider.future);

      final ahora = DateTime.now();
      final enVentana = signos.where((s) => ahora.difference(s.fecha) <= _ventana.duration).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

      final porDia = <String, Signo>{};
      for (final s in enVentana) {
        final key =
            '${s.fecha.year.toString().padLeft(4, '0')}-${s.fecha.month.toString().padLeft(2, '0')}-${s.fecha.day.toString().padLeft(2, '0')}';
        porDia.putIfAbsent(key, () => s);
        if (porDia.length >= _ventana.dias) break;
      }
      final seleccion = porDia.entries.toList()..sort((a, b) => b.value.fecha.compareTo(a.value.fecha));

      const nombrePaciente = 'Paciente';
      final inicio = ahora.subtract(Duration(days: _ventana.dias));
      final rangoFecha = '${inicio.day}/${inicio.month}/${inicio.year} a ${ahora.day}/${ahora.month}/${ahora.year}';
      
      // Generar prompt en formato EXACTO que espera el backend (igual que la web)
      final prompt = _generarPromptResumido(enVentana, nombrePaciente, rangoFecha);
      debugPrint('📝 PROMPT ENVIADO:\n$prompt');

      final dio = ref.read(dioProvider);
      final llm = LlmRemote(dio);
      final tipo = _tipoMap[opcion] ?? 'general';
      
      debugPrint('📡 Llamando a backend con ${enVentana.length} signos');
      
      // NO usar forceOllama - dejar que el backend use sus reglas locales optimizadas
      // Esto es igual que el web: fast=1, tipo=general, SIN forceOllama
      final texto = await llm.recomendacion(
        prompt, 
        tipo: tipo, 
        fast: true, // Usar reglas locales rápidas del backend
      );
      debugPrint('✅ Respuesta recibida: ${texto.length} chars');

      _typing = false;
      _mensajes.add(_Msg.assistant(texto, suffix: ' — ${_ventana.label}'));
      setState(() {});
      await _scrollBottom();
    } catch (e, stack) {
      debugPrint('❌ Error IA: $e');
      debugPrint('Stack: $stack');
      _typing = false;
      // Mostrar error real para debugging
      final errorMsg = e.toString().contains('SocketException') 
          ? 'Error de conexión. Verifica tu internet.'
          : e.toString().contains('TimeoutException')
              ? 'La IA tardó demasiado en responder. Intenta de nuevo.'
              : 'Error al obtener recomendación: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
      _mensajes.add(_Msg.assistant(errorMsg));
      setState(() {});
      await _scrollBottom();
    } finally {
      _enviando = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final signosAsync = ref.watch(_misSignosProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Consejos de salud (IA)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          signosAsync.maybeWhen(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            orElse: () => const SizedBox(height: 8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<_Ventana>(
              segments: const [
                ButtonSegment(value: _Ventana.d7, label: Text('7 días')),
                ButtonSegment(value: _Ventana.d15, label: Text('15 días')),
                ButtonSegment(value: _Ventana.d30, label: Text('30 días')),
              ],
              selected: {_ventana},
              onSelectionChanged: (s) => setState(() => _ventana = s.first),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: _mensajes.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (_typing && i == _mensajes.length) {
                  return const _TypingBubble();
                }
                final m = _mensajes[i];
                return _ChatBubble(msg: m);
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : () => _enviarOpcion(_opcionUnica),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text(
                      _opcionUnica,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mapea el tipo interno a nombre legible con acentos
String _formatearTipoSigno(String tipo) {
  const mapa = {
    'presion_arterial': 'Presión arterial',
    'frecuencia_cardiaca': 'Frecuencia cardíaca',
    'temperatura': 'Temperatura',
    'saturacion_oxigeno': 'Saturación oxígeno',
    'glucosa': 'Glucosa',
    'peso': 'Peso',
    'frecuencia_respiratoria': 'Frecuencia respiratoria',
  };
  return mapa[tipo.toLowerCase()] ?? tipo.replaceAll('_', ' ');
}

/// Agrega unidades al valor según el tipo de signo
String _formatearValorConUnidad(String tipo, String valor) {
  switch (tipo.toLowerCase()) {
    case 'presion_arterial':
      return '$valor mmHg';
    case 'frecuencia_cardiaca':
      return '$valor lpm';
    case 'frecuencia_respiratoria':
      return '$valor rpm';
    case 'temperatura':
      // Verificar si ya tiene unidad
      if (valor.contains('°') || valor.contains('C')) return valor;
      return '$valor °C';
    case 'saturacion_oxigeno':
      if (valor.contains('%')) return valor;
      return '$valor%';
    case 'glucosa':
      return '$valor mg/dL';
    case 'peso':
      return '$valor kg';
    default:
      return valor;
  }
}

/// Detecta si hay signos vitales fuera de rangos normales
bool _tieneSignosAlterados(List<Signo> signos) {
  for (final signo in signos) {
    final tipo = signo.tipo.toLowerCase();
    final valor = signo.valor;
    
    // Presión arterial (90/60 - 120/80 normal)
    if (tipo.contains('presion') || tipo.contains('arterial')) {
      final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(valor);
      if (match != null) {
        final sistolica = int.tryParse(match.group(1)!) ?? 0;
        final diastolica = int.tryParse(match.group(2)!) ?? 0;
        if (sistolica >= 140 || sistolica < 90 || diastolica >= 90 || diastolica < 60) {
          return true;
        }
      }
    }
    
    // Frecuencia cardíaca (60-100 lpm normal)
    if (tipo.contains('cardiaca') || tipo.contains('pulso')) {
      final val = _extraerNumero(valor);
      if (val != null && (val > 100 || val < 60)) return true;
    }
    
    // Frecuencia respiratoria (12-20 rpm normal)
    if (tipo.contains('respiratoria')) {
      final val = _extraerNumero(valor);
      if (val != null && (val > 20 || val < 12)) return true;
    }
    
    // Temperatura (36-37.2 °C normal) - ALERTA si < 35 o >= 38
    if (tipo.contains('temperatura')) {
      final val = _extraerNumero(valor);
      if (val != null && (val >= 38 || val < 35)) return true;
    }
    
    // Saturación O2 (>= 95% normal)
    if (tipo.contains('saturacion') || tipo.contains('oxigeno') || tipo.contains('spo2')) {
      final val = _extraerNumero(valor);
      if (val != null && val < 95) return true;
    }
    
    // Glucosa (70-99 mg/dL normal en ayunas)
    if (tipo.contains('glucosa')) {
      final val = _extraerNumero(valor);
      if (val != null && (val >= 126 || val < 70)) return true;
    }
  }
  return false;
}

/// Extrae el primer número de un texto
double? _extraerNumero(String texto) {
  final match = RegExp(r'[\d.]+').firstMatch(texto);
  return match != null ? double.tryParse(match.group(0)!) : null;
}

/// Genera un prompt resumido similar al de la web
String _generarPromptResumido(List<Signo> signos, String nombrePaciente, String rangoFecha) {
  if (signos.isEmpty) return "No hay datos.";

  // 1. Agrupar por tipo
  final Map<String, List<Signo>> agrupados = {};
  for (var s in signos) {
    if (!agrupados.containsKey(s.tipo)) agrupados[s.tipo] = [];
    agrupados[s.tipo]!.add(s);
  }

  // 2. Generar líneas de resumen
  final List<String> lineas = [];
  
  agrupados.forEach((tipoInterno, lista) {
    // Ordenar por fecha (más antiguo a más reciente)
    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    
    final ultimo = lista.last;
    final n = lista.length;
    // Formato de fecha DD/MM/YYYY
    final fechaStr = "${ultimo.fecha.day}/${ultimo.fecha.month}/${ultimo.fecha.year}";
    final valorUltimo = ultimo.valor;
    
    // Nombre bonito del tipo
    final nombreTipo = _formatearTipoSigno(tipoInterno); // Helper existente
    final valorConUnidad = _formatearValorConUnidad(tipoInterno, valorUltimo);
    final ultTxt = "$valorConUnidad ($fechaStr)";
    
    // Intentar extraer números para estadísticas (ignorar PA tipo 120/80)
    final nums = lista
        .where((s) => !s.valor.contains('/'))
        .map((s) => _extraerNumero(s.valor)) // Usar helper existente
        .where((v) => v != null)
        .toList();

    if (nums.length >= 2) {
      final min = nums.reduce((curr, next) => curr! < next! ? curr : next);
      final max = nums.reduce((curr, next) => curr! > next! ? curr : next);
      final suma = nums.fold<double>(0, (prev, element) => prev + element!);
      final prom = suma / nums.length;
      
      // Formato con estadísticas
      lineas.add("$nombreTipo: n=$n, últ=$ultTxt, min=${min!.toStringAsFixed(1)}, max=${max!.toStringAsFixed(1)}, prom=${prom.toStringAsFixed(1)}");
    } else {
      // Formato simple (solo último valor)
      lineas.add("$nombreTipo: n=$n, últ=$ultTxt");
    }
  });

  return """
Paciente: $nombrePaciente
Rango: $rangoFecha
Total de mediciones: ${signos.length}

Resumen por signo (compacto):
${lineas.join('\n')}
""";
}

class _Msg {
  final bool isUser;
  final String text;
  final DateTime at;
  final String? suffix;

  _Msg._(this.isUser, this.text, this.at, {this.suffix});

  factory _Msg.user(String text) => _Msg._(true, text, DateTime.now());
  factory _Msg.assistant(String text, {String? suffix}) =>
      _Msg._(false, text, DateTime.now(), suffix: suffix);
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final ts = '${msg.at.hour.toString().padLeft(2, '0')}:${msg.at.minute.toString().padLeft(2, '0')}';
    final bg = msg.isUser ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = msg.isUser ? Colors.white : Colors.black87;
    final align = msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = msg.isUser
        ? const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
    )
        : const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(msg.isUser ? 60 : 12, 6, msg.isUser ? 12 : 60, 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            decoration: BoxDecoration(color: bg, borderRadius: radius),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: align,
              children: [
                Text(
                  msg.text + (msg.suffix != null ? msg.suffix! : ''),
                  style: TextStyle(color: fg, fontSize: 16, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(ts, style: TextStyle(color: msg.isUser ? Colors.white70 : Colors.black45, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 60, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, __) {
              final t = _ac.value;
              final op1 = (t < 0.33) ? 1.0 : 0.3;
              final op2 = (t >= 0.33 && t < 0.66) ? 1.0 : 0.3;
              final op3 = (t >= 0.66) ? 1.0 : 0.3;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(op1),
                  const SizedBox(width: 4),
                  _dot(op2),
                  const SizedBox(width: 4),
                  _dot(op3),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      ),
    );
  }
}