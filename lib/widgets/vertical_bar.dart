import 'package:flutter/material.dart';

class VerticalBar extends StatelessWidget {
  final double value; // valor actual
  final double maxValue; // valor máximo
  final Color color; // color de la barra
  final String label; // etiqueta, por ejemplo "RPM"

  const VerticalBar({
    super.key,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = 200.0; // altura total de la barra
    final filledHeight = (value / maxValue) * barHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 20,
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              width: 20,
              height: filledHeight.clamp(0, barHeight),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(
          value.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
