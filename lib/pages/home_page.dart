import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sensor.dart';
import '../services/simulator_service.dart';
import '../services/obd_service.dart';
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

  Map<String, Sensor> sensors = {
    'RPM': Sensor(name: 'RPM', value: 0, unit: 'rpm'),
    'SPEED': Sensor(name: 'SPEED', value: 0, unit: 'km/h'),
    'COOLANT': Sensor(name: 'COOLANT', value: 0, unit: '°C'),
    'OIL': Sensor(name: 'OIL', value: 0, unit: '°C'),
  };

  Timer? _dataTimer;
  final List<String> logs = [];

  void _addLog(String msg) {
    setState(() {
      logs.insert(0, msg);
      if (logs.length > 100) logs.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();

    _obdService.logCallback = _addLog;

    if (simulateMode) {
      _simulator.startSimulation(_updateSensors);
    } else {
      _requestPermissions().then((granted) {
        if (!granted) {
          _addLog('❌ Permisos necesarios no concedidos');
          return;
        }
        _initOBDConnection().then((_) => _startOBDLoop());
      });
    }
  }

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
    setState(() {
      data.forEach((key, value) {
        sensors[key] = value;
      });
    });
  }

  Future<void> _initOBDConnection() async {
    try {
      await _obdService.connectToElm327();
      _addLog('✅ Conectado al adaptador ELM327');
    } catch (e) {
      _addLog('❌ Error al conectar: $e');
    }
  }

  /// Parseo mejorado para respuestas OBD con cabeceras 7E8
  double parseOBDResponse(String response, String pid) {
    try {
      // Limpiamos todo lo que no sea hexadecimal
      final clean = response
          .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
          .toUpperCase();

      if (clean.length < 4) return 0;

      _addLog('Parseando: $clean para PID: $pid');

      // Buscamos patrones comunes en respuestas OBD
      // Patrón 1: Respuesta directa 41 <PID> <datos>
      // Patrón 2: Respuesta multi-frame 7E8 <longitud> 41 <PID> <datos>

      String dataToParse = clean;

      // Si la respuesta contiene 7E8 (cabecera de frame múltiple)
      if (clean.contains('7E8')) {
        int sevenE8Index = clean.indexOf('7E8');
        if (sevenE8Index + 6 <= clean.length) {
          // Saltamos "7E8" y tomamos el byte de longitud
          String lengthByte = clean.substring(
            sevenE8Index + 3,
            sevenE8Index + 5,
          );
          try {
            int dataLength = int.parse(lengthByte, radix: 16);
            // Los datos comienzan después de 7E8 + longitud (2 chars)
            int dataStart = sevenE8Index + 5;
            int dataEnd = dataStart + (dataLength * 2);

            if (dataEnd <= clean.length) {
              dataToParse = clean.substring(dataStart, dataEnd);
              _addLog('Extraídos datos multi-frame: $dataToParse');
            }
          } catch (e) {
            _addLog('Error parseando longitud: $e');
          }
        }
      }

      // Buscamos 41 <PID> en los datos extraídos
      final pidHex = pid.substring(2); // Removemos el "01" del PID
      final targetPattern = '41$pidHex';
      int patternIndex = dataToParse.indexOf(targetPattern);

      if (patternIndex != -1) {
        int dataStart =
            patternIndex + 4; // Saltamos "41" + PID (2 bytes = 4 chars)

        switch (pid) {
          case '010C': // RPM: (A * 256 + B) / 4
            if (dataStart + 4 <= dataToParse.length) {
              String byteA = dataToParse.substring(dataStart, dataStart + 2);
              String byteB = dataToParse.substring(
                dataStart + 2,
                dataStart + 4,
              );
              int a = int.parse(byteA, radix: 16);
              int b = int.parse(byteB, radix: 16);
              final value = ((a * 256) + b) / 4.0;
              _addLog('RPM parseado: $value (bytes: $byteA $byteB)');
              return value;
            }
            break;

          case '010D': // SPEED: A
            if (dataStart + 2 <= dataToParse.length) {
              String byteA = dataToParse.substring(dataStart, dataStart + 2);
              final value = int.parse(byteA, radix: 16).toDouble();
              _addLog('SPEED parseado: $value (byte: $byteA)');
              return value;
            }
            break;

          case '0105': // COOLANT: A - 40
            if (dataStart + 2 <= dataToParse.length) {
              String byteA = dataToParse.substring(dataStart, dataStart + 2);
              final value = int.parse(byteA, radix: 16).toDouble() - 40.0;
              _addLog('COOLANT parseado: $value (byte: $byteA)');
              return value;
            }
            break;

          case '015C': // OIL TEMP: A - 40 (mismo cálculo que coolant)
            if (dataStart + 2 <= dataToParse.length) {
              String byteA = dataToParse.substring(dataStart, dataStart + 2);
              final value = int.parse(byteA, radix: 16).toDouble() - 40.0;
              _addLog('OIL parseado: $value (byte: $byteA)');
              return value;
            }
            break;
        }
      } else {
        _addLog('Patrón 41$pidHex no encontrado en: $dataToParse');
      }

      return 0;
    } catch (e) {
      _addLog('❌ Error en parseOBDResponse: $e');
      return 0;
    }
  }

  void _startOBDLoop() {
    const pids = {
      'RPM': '010C',
      'SPEED': '010D',
      'COOLANT': '0105',
      'OIL': '015C',
    };

    _dataTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;

      final Map<String, Sensor> newData = {};

      for (final entry in pids.entries) {
        try {
          final response = await _obdService.sendCommand(
            entry.value,
            timeout: const Duration(seconds: 3),
          );

          _addLog('CMD: ${entry.value} -> RESP: $response');

          if (response.isNotEmpty) {
            final value = parseOBDResponse(response, entry.value);
            if (value > 0 || entry.key == 'SPEED') {
              // Speed puede ser 0
              newData[entry.key] = Sensor(
                name: entry.key,
                value: value,
                unit: entry.key == 'RPM'
                    ? 'rpm'
                    : (entry.key == 'SPEED' ? 'km/h' : '°C'),
              );
            }
          }
        } catch (e) {
          _addLog('❌ Error leyendo ${entry.key}: $e');
        }
      }

      if (newData.isNotEmpty) _updateSensors(newData);
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
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: sensors.values.map((sensor) {
                  return CircularGauge(
                    sensor: sensor,
                    maxValue: sensor.name == 'RPM'
                        ? 7000
                        : (sensor.name == 'SPEED' ? 240 : 140),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            height: 200,
            color: Colors.black87,
            child: ListView.builder(
              reverse: true,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Text(
                  logs[index],
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
