
abstract class AuthRepository {
  Future<void> loginPaciente(String cedula, String contrasena);
  Future<bool> isValidSession();
  Future<void> logout();
}
