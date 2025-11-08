import 'package:flutter/material.dart';
import '../models/sensor.dart';

class CircularGauge extends StatelessWidget {
  final Sensor sensor;
  final double maxValue;

  const CircularGauge({
    super.key,
    required this.sensor,
    required this.maxValue,
  });

  Color _getColor(double value) {
    double percentage = value / maxValue;
    if (percentage < 0.6) return Colors.greenAccent;
    if (percentage < 0.85) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    double percentage = (sensor.value / maxValue).clamp(0.0, 1.0);
    Color color = _getColor(sensor.value);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Círculo de fondo
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 10,
                color: color,
                backgroundColor: Colors.grey.shade900,
              ),
            ),
            // Valor en el centro
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sensor.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "${sensor.value.toStringAsFixed(0)} ${sensor.unit}",
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
