
import 'package:dio/dio.dart';

class AuthRemote {
  final Dio _dio;
  AuthRemote(this._dio);
  Future<String> loginPaciente({required String cedula, required String contrasena}) async {
    final res = await _dio.post('/auth/login-paciente', data: {'cedula': cedula, 'contrasena': contrasena});
    return res.data['token'] as String;
  }
  Future<bool> checkToken() async {
    final res = await _dio.get('/auth/check-token');
    return res.statusCode == 200;
  }
}
