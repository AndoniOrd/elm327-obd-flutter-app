// lib/services/obd_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';

class OBDService {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  final _readBuffer = StringBuffer();
  Completer<String>? _pendingResponse;

  /// Conecta al adaptador Vgate iCar Pro (Bluetooth clásico / SPP)
  Future<void> connectToElm327() async {
    print('🔍 Buscando adaptadores Bluetooth emparejados...');
    final bondedDevices = await FlutterBluetoothSerial.instance
        .getBondedDevices();

    // Busca por nombre (vgate, vlink, obd, etc)
    final device = bondedDevices.firstWhere(
          (d) => d.name == 'Android-Vlink',
      orElse: () {
        // Si no encuentra exactamente 'Android-Vlink', busca por nombre parcial
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

    print('✅ Dispositivo encontrado: ${device.name} (${device.address})');
    print('🔗 Conectando vía SPP...');

    _connection = await BluetoothConnection.toAddress(device.address);
    print('✅ Conectado a ${device.name}');

    _inputSubscription = _connection!.input!.listen(
      (data) {
        final chunk = ascii.decode(data, allowInvalid: true);
        _readBuffer.write(chunk);
        // Los ELM327 terminan sus respuestas con el prompt '>'
        if (_readBuffer.toString().contains('>')) {
          final response = _readBuffer.toString();
          _readBuffer.clear();
          _pendingResponse?.complete(response);
          _pendingResponse = null;
        }
      },
      onDone: () {
        print('🔌 Conexión finalizada por el dispositivo');
      },
    );
  }

  /// Envía un comando OBD-II al ELM327 y devuelve la respuesta
  Future<String> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('No hay conexión activa con el adaptador OBD');
    }

    _pendingResponse = Completer<String>();
    _connection!.output.add(utf8.encode('$command\r'));
    await _connection!.output.allSent;

    try {
      final raw = await _pendingResponse!.future.timeout(timeout);
      final clean = _cleanResponse(raw);
      print('📡 CMD: $command → RESP: $clean');
      return clean;
    } on TimeoutException {
      print('⏰ Timeout esperando respuesta de $command');
      return 'NO DATA';
    } catch (e) {
      print('❌ Error en sendCommand: $e');
      return 'ERROR';
    }
  }

  /// Limpia el texto de la respuesta OBD (quita >, CR/LF, etc)
  String _cleanResponse(String input) {
    return input
        .replaceAll(RegExp(r'(\r|\n|>)'), ' ')
        .replaceAll(RegExp(r'SEARCHING\.\.\.'), '')
        .replaceAll(RegExp(r'NO DATA'), '')
        .trim();
  }

  /// Cierra la conexión
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    await _connection?.close();
    _connection = null;
    print('🔒 Conexión cerrada.');
  }
}
