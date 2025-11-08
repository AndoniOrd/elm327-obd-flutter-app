import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class OBDService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _readChar;

  Future<void> connectToElm327() async {
    var flutterBlue = FlutterBluePlus();

    print('🔍 Escaneando dispositivos ELM327...');
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Escuchar resultados del escaneo
    List<ScanResult> results = [];
    await for (final snapshot in FlutterBluePlus.scanResults) {
      results = snapshot;
      if (results.any((r) =>
          r.device.name.contains('OBD') ||
          r.device.name.contains('ELM'))) {
        break;
      }
    }

    await FlutterBluePlus.stopScan();

    final elmResult = results.firstWhere(
      (r) => r.device.name.contains('OBD') || r.device.name.contains('ELM'),
      orElse: () => throw Exception('❌ No se encontró un ELM327'),
    );

    _device = elmResult.device;

    print('✅ ELM327 encontrado: ${_device!.name}');
    await _device!.connect();

    // Buscar servicios
    List<BluetoothService> services = await _device!.discoverServices();
    for (var service in services) {
      for (var c in service.characteristics) {
        if (c.properties.write) _writeChar = c;
        if (c.properties.notify || c.properties.read) _readChar = c;
      }
    }

    print('🔗 Conectado y listo para comandos OBD.');
  }

  Future<String> sendCommand(String cmd) async {
    if (_writeChar == null) return 'No conectado';

    final data = ascii.encode('$cmd\r');
    await _writeChar!.write(data, withoutResponse: true);

    await Future.delayed(const Duration(milliseconds: 500));
    final response = await _readChar?.read();
    return ascii.decode(response ?? []);
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
  }
}
