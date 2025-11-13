import 'dart:async';
import 'dart:math';
import '../models/sensor.dart';

class SimulatorService {
  final Random _random = Random();
  Timer? _timer;
  double _rpm = 900;
  double _speed = 0;
  double _coolant = 60;
  double _oil = 55;
  double _battery = 13.8;

  void startSimulation(Function(Map<String, Sensor>) onData) {
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _simulateEngineBehavior();

      final sensors = {
        'rpm': Sensor(name: 'RPM', value: _rpm, unit: 'rpm'),
        'speed': Sensor(name: 'Velocidad', value: _speed, unit: 'km/h'),
        'coolant': Sensor(name: 'Refrigerante', value: _coolant, unit: '°C'),
        'oil': Sensor(name: 'Aceite', value: _oil, unit: '°C'),
        'battery': Sensor(name: 'Batería', value: _battery, unit: 'V'),
      };

      onData(sensors);
    });
  }

  void _simulateEngineBehavior() {
    // 🔄 Simulación de aceleración progresiva hasta 120 km/h
    if (_speed < 120) {
      _speed += 2.5 + _random.nextDouble() * 1.5; // sube más rápido
    } else {
      // una vez alcanza 120, fluctúa suavemente alrededor
      _speed += sin(DateTime.now().millisecond / 250.0) * 0.8;
      _speed = _speed.clamp(118, 122);
    }

    // RPM ajustado según la velocidad (entre 1000 y 3200 aprox)
    _rpm = 900 + (_speed * 20) + _random.nextDouble() * 150;
    _rpm = _rpm.clamp(800, 3500);

    // Temperaturas suben lentamente y se estabilizan
    if (_coolant < 90) _coolant += 0.06 + _random.nextDouble() * 0.1;
    if (_oil < 95) _oil += 0.04 + _random.nextDouble() * 0.1;

    // Batería fluctúa suavemente (simula alternador)
    _battery = 13.6 + sin(DateTime.now().millisecond / 500.0) * 0.15;
  }

  void stopSimulation() {
    _timer?.cancel();
  }
}
