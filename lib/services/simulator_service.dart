import 'dart:async';
import '../models/sensor.dart';

class SimulatorService {
  Timer? _timer;
  int _counter = 0;

  void startSimulation(Function(Map<String, Sensor>) onData) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _counter++;
      Map<String, Sensor> data = {
        'rpm': Sensor(
          name: 'RPM', 
          value: 1500 + (1000 * (_counter % 10) / 10), 
          unit: 'rpm'
        ),
        'coolant': Sensor(
          name: 'Coolant Temp', 
          value: 75 + (5 * (_counter % 10) / 10), 
          unit: '°C'
        ),
      };
      onData(data);
    });
  }

  void stopSimulation() {
    _timer?.cancel();
  }
}