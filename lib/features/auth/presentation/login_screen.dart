
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _cedula = TextEditingController();
  final _pwd = TextEditingController();
  bool _loading = false; String? _error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso Paciente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _cedula, decoration: const InputDecoration(labelText: 'Cédula')),
          TextField(controller: _pwd, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: _loading ? null : () async {
              setState(() { _loading = true; _error = null; });
              try {
                await ref.read(authRepoProvider).loginPaciente(_cedula.text.trim(), _pwd.text);
                if (!mounted) return;
                context.go('/home');
              } catch (e) { setState(() => _error = 'Credenciales inválidas o error de conexión.'); }
              finally { setState(() => _loading = false); }
            },
            child: _loading ? const CircularProgressIndicator() : const Text('Ingresar'),
          ),
        ]),
      ),
    );
  }
}
