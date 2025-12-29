import 'package:flutter/material.dart';

class TermsDialog extends StatelessWidget {
  const TermsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security, color: Color(0xFF0D47A1)),
          SizedBox(width: 8),
          Text('Términos y Condiciones'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protección de Datos Personales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Su privacidad es importante para nosotros. Al utilizar esta aplicación, usted acepta que sus datos de salud (signos vitales, citas, etc.) sean procesados y almacenados de manera segura para el seguimiento de su tratamiento médico.\n\n'
              '1. Los datos serán utilizados únicamente con fines médicos.\n'
              '2. Usted tiene derecho a solicitar la eliminación de sus datos.\n'
              '3. La información es confidencial entre usted y su médico.\n\n'
              'Por favor, confirme que acepta estos términos para continuar.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // Rechazar
          child: const Text('Rechazar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true), // Aceptar
          child: const Text('Aceptar y Continuar'),
        ),
      ],
    );
  }
}
