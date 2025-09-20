import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monitoreo_movil/features/auth/providers.dart';
import 'package:monitoreo_movil/features/llm/data/llm_remote.dart';
import 'package:monitoreo_movil/features/signos/data/signos_remote.dart';
import 'package:monitoreo_movil/features/paciente/domain/entities.dart';

/// Opciones predefinidas para adultos mayores (sin escribir)
const _opciones = <String>[
  'Revisión general',
  '¿Hay algo preocupante?',
  'Qué vigilar',
  'Hábitos y cuidados',
];

/// Ventanas fijas 7 / 15 / 30 días
enum _Ventana { d7, d15, d30 }

extension _VentanaX on _Ventana {
  int get dias {
    switch (this) {
      case _Ventana.d7: return 7;
      case _Ventana.d15: return 15;
      case _Ventana.d30: return 30;
    }
  }
  String get label => '$dias días';
  Duration get duration => Duration(days: dias);
}

/// Proveedor de signos (para armar el prompt internamente)
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

  _Ventana _ventana = _Ventana.d30; // por defecto 30 días
  bool _enviando = false;
  bool _typing = false;

  final List<_Msg> _mensajes = []; // chat history

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    // 1) Muestra burbuja del "usuario"
    _mensajes.add(_Msg.user(opcion));
    setState(() {});
    await _scrollBottom();

    // 2) Muestra indicador "escribiendo…"
    _typing = true;
    setState(() {});
    await _scrollBottom();

    try {
      // 3) Trae signos (no se muestran al paciente)
      final signos = await ref.read(_misSignosProvider.future);

      // 4) Filtra por ventana y prioriza 1 por día (máx N días)
      final ahora = DateTime.now();
      final enVentana = signos
          .where((s) => ahora.difference(s.fecha) <= _ventana.duration)
          .toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));

      final porDia = <String, Signo>{}; // yyyy-mm-dd -> Signo más reciente de ese día
      for (final s in enVentana) {
        final key = '${s.fecha.year.toString().padLeft(4, '0')}-'
            '${s.fecha.month.toString().padLeft(2, '0')}-'
            '${s.fecha.day.toString().padLeft(2, '0')}';
        porDia.putIfAbsent(key, () => s);
        if (porDia.length >= _ventana.dias) break;
      }
      final seleccion = porDia.entries.toList()
        ..sort((a, b) => b.value.fecha.compareTo(a.value.fecha));

      // 5) Construye prompt “behind the scenes” (no se muestra)
      final buffer = StringBuffer();
      for (final e in seleccion) {
        final s = e.value;
        final f = e.key; // yyyy-mm-dd
        buffer.writeln('- ${s.tipo.replaceAll("_", " ")}: ${s.valor} (fecha: $f)');
      }

      final prompt = '''
Eres un asistente clínico. Habla con lenguaje muy claro y amable para adultos mayores.
Analiza los signos vitales recientes y ofrece recomendaciones prácticas y seguras.
Evita diagnósticos definitivos. Indica cuándo consultar al médico y hábitos saludables.

Ventana analizada: últimos ${_ventana.dias} días (máximo 1 registro por día, hasta ${_ventana.dias} en total).
Signos del paciente (no mostrar al usuario):
${buffer.isEmpty ? '(sin signos en la ventana seleccionada)' : buffer.toString()}

Preferencia del paciente:
$opcion

Formato de salida:
1) Resumen claro
2) Recomendaciones (pasos concretos y fáciles)
3) Señales de alarma (si aplica)
''';

      // 6) Llamada al backend LLM
      final dio = ref.read(dioProvider);
      final llm = LlmRemote(dio);
      final texto = await llm.recomendacion(prompt);

      // 7) Reemplaza typing y añade respuesta del asistente
      _typing = false;
      _mensajes.add(_Msg.assistant(texto, suffix: ' — ${_ventana.label}'));
      setState(() {});
      await _scrollBottom();
    } catch (_) {
      _typing = false;
      _mensajes.add(_Msg.assistant('No se pudo obtener una recomendación en este momento.'));
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
          // Encabezado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: const [
                Expanded(
                  child: Text('Consejos de salud (IA)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Línea de estado de carga de signos (no muestra datos)
          signosAsync.maybeWhen(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            orElse: () => const SizedBox(height: 8),
          ),

          // Segmento de 7/15/30 días
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

          // Chat (historial)
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

          // Botones de opciones grandes (quick replies)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _opciones.map((op) {
                return SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : () => _enviarOpcion(op),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text(op, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== MODELOS Y WIDGETS DE CHAT ======

class _Msg {
  final bool isUser;         // true = paciente (burbuja derecha)
  final String text;         // contenido visible
  final DateTime at;         // tiempo
  final String? suffix;      // opcional: " — 30 días" etc.

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
    final bg = msg.isUser ? const Color(0xFF1976D2) : Colors.grey.shade100;
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
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(
          color: Colors.black38, shape: BoxShape.circle)),
    );
  }
}
