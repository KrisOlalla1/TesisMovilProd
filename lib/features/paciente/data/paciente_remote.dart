import 'package:dio/dio.dart';
import '../domain/entities.dart';

class PacienteRemote {
  final Dio _dio;
  PacienteRemote(this._dio);

  Future<Paciente> me() async {
    final r = await _dio.get('/pacientes/me');

    dynamic body = r.data;

    // Soporta varias formas de respuesta:
    // { ...objetoPaciente }  |  { data: {...} }  |  { paciente: {...} }
    Map<String, dynamic> obj;
    if (body is Map<String, dynamic>) {
      if (body['data'] is Map<String, dynamic>) {
        obj = body['data'] as Map<String, dynamic>;
      } else if (body['paciente'] is Map<String, dynamic>) {
        obj = body['paciente'] as Map<String, dynamic>;
      } else {
        obj = body;
      }
    } else {
      throw Exception('Respuesta inesperada de /pacientes/me');
    }

    return Paciente.fromJson(obj);
  }
}
