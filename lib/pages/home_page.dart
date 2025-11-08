import 'package:elm327_obd_flutter_app/widgets/circular_gauge.dart';
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
    _simulator.startSimulation((data) {
      if (mounted) setState(() => sensors = data);
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('OBD Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
  padding: const EdgeInsets.all(16.0),
  child: sensors.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            CircularGauge(sensor: sensors['rpm']!, maxValue: 7000),
            CircularGauge(sensor: sensors['speed']!, maxValue: 240),
            CircularGauge(sensor: sensors['coolant']!, maxValue: 120),
            CircularGauge(sensor: sensors['oil']!, maxValue: 140),
          ],
        ),
),
    );
  }
}
