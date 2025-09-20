import 'package:flutter/material.dart';
import 'calendario_screen.dart';
import 'signos_screen.dart';
import 'citas_screen.dart';
import 'recomendacion_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  final _tabs = const [
    CalendarioScreen(),
    SignosScreen(),
    CitasScreen(),
    RecomendacionScreen(), // ⬅️ volvió IA
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paciente')),
      body: _tabs[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Signos'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Citas'),
          NavigationDestination(icon: Icon(Icons.psychology), label: 'IA'),
        ],
      ),
    );
  }
}
