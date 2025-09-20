class Paciente {
  final String id;
  final String nombre;
  final List<String> signosHabilitados;

  Paciente({
    required this.id,
    required this.nombre,
    required this.signosHabilitados,
  });

  static List<String> _extractEnabled(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (raw is Map) {
      final out = <String>[];
      raw.forEach((k, v) {
        final vv = (v is String) ? v.toLowerCase() : v;
        final ok = vv == true || vv == 'true' || vv == 1 || vv == '1';
        if (ok) out.add(k.toString());
      });
      return out;
    }
    return <String>[];
  }

  factory Paciente.fromJson(Map<String, dynamic> j) {
    final rawSignos = j['signos_habilitados'] ??
        j['signosHabilitados'] ??
        j['parametros_habilitados'] ??
        j['parametrosHabilitados'] ??
        j['habilitados'] ??
        j['signos'];

    final signos = _extractEnabled(rawSignos);
    final nombreCalc = (j['nombre_completo'] ?? j['nombre'] ?? '').toString();

    return Paciente(
      id: (j['_id'] ?? j['id']).toString(),
      nombre: nombreCalc,
      signosHabilitados: signos,
    );
  }
}

class Signo {
  final String id;       // <-- para editar
  final String tipo;
  final String valor;
  final DateTime fecha;

  Signo({required this.id, required this.tipo, required this.valor, required this.fecha});

  factory Signo.fromJson(Map<String, dynamic> j) {
    final fechaRaw = j['fecha_registro'] ?? j['fecha'] ?? j['createdAt'];
    final parsed = fechaRaw is String ? DateTime.tryParse(fechaRaw) : null;

    return Signo(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      tipo: (j['tipo'] ?? j['nombre'] ?? '').toString(),
      valor: (j['valor'] ?? j['medida'] ?? '').toString(),
      fecha: parsed ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toBody() => {
    'tipo': tipo,
    'valor': valor,
    'fecha_registro': fecha.toIso8601String(),
  };
}

class Cita {
  final String id;
  final String titulo;
  final String mensaje;
  final DateTime fechaCita;
  final String estado;
  final bool leida;

  Cita({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.fechaCita,
    required this.estado,
    required this.leida,
  });

  factory Cita.fromJson(Map<String, dynamic> j) {
    final fechaRaw = j['fecha_cita'] ?? j['fecha'] ?? j['cuando'] ?? j['scheduledAt'];
    final parsed = fechaRaw is String ? DateTime.tryParse(fechaRaw) : null;

    return Cita(
      id: (j['_id'] ?? j['id']).toString(),
      titulo: (j['titulo'] ?? j['title'] ?? '').toString(),
      mensaje: (j['mensaje'] ?? j['message'] ?? '').toString(),
      fechaCita: parsed ?? DateTime.now(),
      estado: (j['estado'] ?? j['status'] ?? '').toString(),
      leida: (j['leida'] ?? j['read'] ?? false) == true,
    );
  }
}
