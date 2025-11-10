import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sensor.dart';
import '../services/simulator_service.dart';
import '../services/obd_Service.dart';
import '../config.dart';
import 'package:elm327_obd_flutter_app/widgets/circular_gauge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SimulatorService _simulator = SimulatorService();
  final OBDService _obdService = OBDService();
  Map<String, Sensor> sensors = {};
  Timer? _dataTimer;

  @override
  void initState() {
    super.initState();

    if (simulateMode) {
      // Simulación pura, nada de plugins
      _simulator.startSimulation(_updateSensors);
    } else {
      // OBD real: primero pedimos permisos
      _requestPermissions().then((granted) {
        if (!granted) {
          print('❌ Permisos necesarios no concedidos');
          return;
        }
        _initOBDConnection().then((_) => _startOBDLoop());
      });
    }
  }

  /// Solicita permisos de Bluetooth y ubicación en Android
  Future<bool> _requestPermissions() async {
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final location = await Permission.location.request();

    return bluetoothConnect.isGranted &&
        bluetoothScan.isGranted &&
        location.isGranted;
  }

  void _updateSensors(Map<String, Sensor> data) {
    if (!mounted) return;
    setState(() => sensors = data);
  }

  Future<void> _initOBDConnection() async {
    try {
      await _obdService.connectToElm327();
      print('✅ Conectado al adaptador ELM327');
    } catch (e) {
      print('❌ Error al conectar: $e');
    }
  }

  void _startOBDLoop() {
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final rpmResponse = await _obdService.sendCommand("010C");
        final speedResponse = await _obdService.sendCommand("010D");
        final coolantResponse = await _obdService.sendCommand("0105");
        final oilResponse = await _obdService.sendCommand("015C");

        setState(() {
          sensors['rpm'] = Sensor(
            name: 'RPM',
            value: _parseRPM(rpmResponse),
            unit: 'rpm',
          );
          sensors['speed'] = Sensor(
            name: 'Speed',
            value: _parseSpeed(speedResponse),
            unit: 'km/h',
          );
          sensors['coolant'] = Sensor(
            name: 'Coolant',
            value: _parseTemp(coolantResponse),
            unit: '°C',
          );
          sensors['oil'] = Sensor(
            name: 'Oil',
            value: _parseTemp(oilResponse),
            unit: '°C',
          );
        });
      } catch (e) {
        print('❌ Error al leer OBD: $e');
      }
    });
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    if (simulateMode) {
      _simulator.stopSimulation();
    } else {
      _obdService.disconnect();
    }
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
                  if (sensors.containsKey('rpm'))
                    CircularGauge(sensor: sensors['rpm']!, maxValue: 7000),
                  if (sensors.containsKey('speed'))
                    CircularGauge(sensor: sensors['speed']!, maxValue: 240),
                  if (sensors.containsKey('coolant'))
                    CircularGauge(sensor: sensors['coolant']!, maxValue: 120),
                  if (sensors.containsKey('oil'))
                    CircularGauge(sensor: sensors['oil']!, maxValue: 140),
                ],
              ),
      ),
    );
  }

  // Convertir respuestas OBD-II a valores numéricos
  double _parseRPM(String response) {
    try {
      final bytes = response
          .split(' ')
          .where((b) => b.isNotEmpty)
          .map((b) => int.parse(b, radix: 16))
          .toList();
      if (bytes.length >= 4) {
        final a = bytes[2];
        final b = bytes[3];
        return (a * 256 + b) / 4.0;
      }
    } catch (_) {}
    return 0;
  }

  double _parseSpeed(String response) {
    try {
      final bytes = response
          .split(' ')
          .where((b) => b.isNotEmpty)
          .map((b) => int.parse(b, radix: 16))
          .toList();
      if (bytes.length >= 3) {
        final a = bytes[2];
        return a.toDouble();
      }
    } catch (_) {}
    return 0;
  }

  double _parseTemp(String response) {
    try {
      final bytes = response
          .split(' ')
          .where((b) => b.isNotEmpty)
          .map((b) => int.parse(b, radix: 16))
          .toList();
      if (bytes.length >= 3) {
        final a = bytes[2];
        return a - 40.0;
      }
    } catch (_) {}
    return 0;
  }
}
