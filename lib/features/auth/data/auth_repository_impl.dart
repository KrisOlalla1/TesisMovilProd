
import '../../../core/secure_storage.dart';
import 'auth_remote.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemote remote;
  AuthRepositoryImpl(this.remote);
  @override
  Future<void> loginPaciente(String cedula, String contrasena) async {
    final token = await remote.loginPaciente(cedula: cedula, contrasena: contrasena);
    await SecureStore.saveToken(token);
  }
  @override
  Future<bool> isValidSession() => remote.checkToken();
  @override
  Future<void> logout() => SecureStore.clear();
}
