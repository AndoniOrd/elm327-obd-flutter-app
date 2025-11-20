import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor.dart';

class PerformanceScreen extends StatefulWidget {
  final Sensor rpm;
  final Sensor speed;
  final Sensor coolant;

  const PerformanceScreen({
    super.key,
    required this.rpm,
    required this.speed,
    required this.coolant,
  });

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  double displayedRPM = 0;
  double displayedSpeed = 0;
  double displayedCoolant = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    displayedRPM = widget.rpm.value;
    displayedSpeed = widget.speed.value;
    displayedCoolant = widget.coolant.value;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        displayedRPM += (widget.rpm.value - displayedRPM) * 0.2;
        displayedSpeed += (widget.speed.value - displayedSpeed) * 0.2;
        displayedCoolant += (widget.coolant.value - displayedCoolant) * 0.2;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _coolantColor(double value) {
    if (value < 80) return Colors.blue;
    if (value < 100) return Colors.green;
    return Colors.red;
  }

  Color _rpmColor(double value) {
    if (value < 3000) return Colors.green;
    if (value < 4500) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final rpmColor = _rpmColor(displayedRPM);
    final rpmPercentage = displayedRPM / 6000;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Performance'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sección RPM simplificada - Barra horizontal en la parte superior
            Container(
              height: 40,
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Barra de RPM
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        // Fondo con gradiente de color
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.3),
                                Colors.orange.withOpacity(0.3),
                                Colors.red.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                        
                        // Barra de progreso
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: (MediaQuery.of(context).size.width - 40) * rpmPercentage,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                rpmColor.withOpacity(0.8),
                                rpmColor.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 5),
                  
                  // Marcas de RPM
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final rpmValue = index * 1000;
                      final color = _rpmColor(rpmValue.toDouble());
                      return Text(
                        '$rpmValue',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            
            // Espacio para la velocidad
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Velocidad grande
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayedSpeed.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'km/h',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Indicador de RPM compacto
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: rpmColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: rpmColor, width: 2),
                      ),
                      child: Text(
                        '${displayedRPM.toStringAsFixed(0)} RPM',
                        style: TextStyle(
                          color: rpmColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Sección inferior con temperatura
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Temperatura del coolant
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _coolantColor(displayedCoolant).withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: _coolantColor(displayedCoolant), width: 2),
                        ),
                        child: Icon(
                          Icons.thermostat,
                          color: _coolantColor(displayedCoolant),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${displayedCoolant.toStringAsFixed(0)}°C',
                            style: TextStyle(
                              color: _coolantColor(displayedCoolant),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'COOLANT',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Indicador de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: displayedCoolant < 90 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: displayedCoolant < 90 ? Colors.green : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          displayedCoolant < 90 ? Icons.check_circle : Icons.warning,
                          color: displayedCoolant < 90 ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayedCoolant < 90 ? 'ÓPTIMO' : 'CALIENTE',
                          style: TextStyle(
                            color: displayedCoolant < 90 ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}