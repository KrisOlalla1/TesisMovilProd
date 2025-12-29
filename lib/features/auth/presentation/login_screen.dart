import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';
import 'terms_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _cedula = TextEditingController();
  final _pwd = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Icono
              const Icon(Icons.health_and_safety, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Monitoreo Salud',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Tarjeta de Login
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _cedula,
                        decoration: const InputDecoration(
                          labelText: 'Cédula',
                          prefixIcon: Icon(Icons.person),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pwd,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 24, width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('INGRESAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepoProvider).loginPaciente(_cedula.text.trim(), _pwd.text);
      if (!mounted) return;

      // Verificar Términos y Condiciones
      final accepted = await _storage.read(key: 'terms_accepted');
      if (accepted != 'true') {
        if (!mounted) return;
        final bool? result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const TermsDialog(),
        );

        if (result == true) {
          await _storage.write(key: 'terms_accepted', value: 'true');
          if (!mounted) return;
          context.go('/home');
        } else {
          // Si rechaza, nos quedamos aquí (o podríamos desloguear)
          setState(() => _error = 'Debe aceptar los términos para continuar.');
        }
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Credenciales inválidas o error de conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
