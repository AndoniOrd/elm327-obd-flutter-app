import 'package:flutter/material.dart';
import '../models/sensor.dart';
import '../services/simulator_service.dart';

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
    
    // Pequeño delay para asegurar que el widget esté montado
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        sensor.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Text(
                        "${sensor.value.toStringAsFixed(1)} ${sensor.unit}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}