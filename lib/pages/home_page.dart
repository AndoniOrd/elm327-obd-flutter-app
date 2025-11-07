import 'package:flutter/material.dart';
import '../models/sensor.dart';
import '../services/simulator_service.dart';
import '../widgets/sensor_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SimulatorService _simulator = SimulatorService();
  Map<String, Sensor> sensors = {};

  @override
  void initState() {
    super.initState();

    // Añadimos un pequeño delay para evitar errores de contexto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _simulator.startSimulation((data) {
        if (mounted) {
          setState(() {
            sensors = data;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _simulator.stopSimulation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD Dashboard'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _simulator.stopSimulation();
              _simulator.startSimulation((data) {
                if (mounted) {
                  setState(() {
                    sensors = data;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: sensors.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando datos del vehículo...'),
                  ],
                ),
              )
            : ListView(
                children: sensors.values.map((sensor) {
                  return SensorCard(
                    sensor: sensor,
                  ); // 👈 Usamos tu nuevo widget
                }).toList(),
              ),
      ),
    );
  }
}
