// lib/services/obd_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class OBDService {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  final _readBuffer = StringBuffer();
  Completer<String>? _pendingResponse;

  void Function(String msg)? logCallback;

  /// Conecta al adaptador Vgate iCar Pro (Bluetooth clásico / SPP)
  Future<void> connectToElm327() async {
    logCallback?.call('🔍 Buscando adaptadores Bluetooth emparejados...');
    final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();

    // Busca por nombre exacto o parcial
    final device = bondedDevices.firstWhere(
      (d) => d.name == 'Android-Vlink',
      orElse: () {
        final fallback = bondedDevices.firstWhere(
          (d) {
            final n = d.name?.toLowerCase() ?? '';
            return n.contains('vgate') || n.contains('icar') || n.contains('vlink');
          },
          orElse: () => throw Exception('❌ No se encontró ningún adaptador Vgate/OBD emparejado.'),
        );
        return fallback;
      },
    );

    logCallback?.call('✅ Dispositivo encontrado: ${device.name} (${device.address})');
    logCallback?.call('🔗 Conectando vía SPP...');

    // Conexión Bluetooth clásico
    _connection = await BluetoothConnection.toAddress(device.address);
    logCallback?.call('✅ Conectado a ${device.name}');

    // Cancela suscripción previa si existía
    await _inputSubscription?.cancel();

    // Escucha la entrada una sola vez
    _inputSubscription = _connection!.input!.listen(
      (data) {
        final chunk = ascii.decode(data, allowInvalid: true);
        _readBuffer.write(chunk);

        if (_readBuffer.toString().contains('>')) {
          final response = _readBuffer.toString();
          _readBuffer.clear();
          _pendingResponse?.complete(response);
          _pendingResponse = null;
        }
      },
      onDone: () => logCallback?.call('🔌 Conexión finalizada por el dispositivo'),
      onError: (err) => logCallback?.call('❌ Error en la conexión: $err'),
    );

    logCallback?.call('⚙️ Inicializando ELM327...');
    await _initializeElm327();
    logCallback?.call('🔗 ELM327 listo para recibir comandos OBD');
  }

  Future<void> _initializeElm327() async {
    final initCmds = ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH1', 'ATSP0'];
    for (final cmd in initCmds) {
      final resp = await sendCommand(cmd);
      logCallback?.call('⚙️ Init: $cmd → $resp');
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<String> sendCommand(String command, {Duration timeout = const Duration(seconds: 2)}) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('No hay conexión activa con el adaptador OBD');
    }

    _pendingResponse = Completer<String>();
    _connection!.output.add(utf8.encode('$command\r'));
    await _connection!.output.allSent;

    try {
      final raw = await _pendingResponse!.future.timeout(timeout);
      final clean = _cleanResponse(raw);
      logCallback?.call('📡 CMD: $command → RESP: $clean');
      return clean;
    } on TimeoutException {
      logCallback?.call('⏰ Timeout esperando respuesta de $command');
      return '';
    } catch (e) {
      logCallback?.call('❌ Error en sendCommand: $e');
      return '';
    }
  }

  String _cleanResponse(String input) {
    return input
        .replaceAll(RegExp(r'(\r|\n|>)'), ' ')
        .replaceAll(RegExp(r'SEARCHING\.\.\.'), '')
        .replaceAll(RegExp(r'NO DATA'), '')
        .trim();
  }

  double parseOBDResponse(String response, String pid) {
    try {
      final clean = response
          .replaceAll(RegExp(r'[^0-9A-Fa-f ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final bytes = clean
          .split(' ')
          .where((b) => b.isNotEmpty)
          .map((b) => int.parse(b, radix: 16))
          .toList();

      if (bytes.isEmpty) return 0;

      final pidByte = int.parse(pid.substring(2), radix: 16);
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == 0x41 && bytes[i + 1] == pidByte) {
          return _decodePID(bytes, i + 1, pid);
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  double _decodePID(List<int> bytes, int pidIndex, String pid) {
    switch (pid) {
      case '010C': // RPM
        if (pidIndex + 2 >= bytes.length) return 0;
        return ((bytes[pidIndex + 1] * 256) + bytes[pidIndex + 2]) / 4.0;
      case '010D': // SPEED
        if (pidIndex + 1 >= bytes.length) return 0;
        return bytes[pidIndex + 1].toDouble();
      case '0105': // COOLANT
      case '015C': // OIL TEMP
        if (pidIndex + 1 >= bytes.length) return 0;
        return bytes[pidIndex + 1] - 40.0;
      default:
        return 0;
    }
  }

  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    await _connection?.close();
    _connection = null;
    logCallback?.call('🔒 Conexión cerrada.');
  }
}
