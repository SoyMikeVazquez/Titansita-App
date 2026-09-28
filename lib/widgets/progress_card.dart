import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../screens/records_screen.dart';

class ProgressCard extends StatelessWidget {
  final UserProfile profile;
  const ProgressCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final lostWeight = (profile.initialWeight - profile.currentWeight).abs();
    final remainingWeight = (profile.currentWeight - profile.targetWeight).abs();
    
    // Determine sign based on goal (losing or gaining weight)
    final isLosing = profile.targetWeight < profile.initialWeight;
    final progressDeltaStr = isLosing 
        ? '-${lostWeight.toStringAsFixed(1)} kg'
        : '+${lostWeight.toStringAsFixed(1)} kg';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu Estatus y Progreso',
                    style: TextStyle(
                      color: Color(0xFF171717),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Edad: ${profile.age} años  •  Estatura: ${profile.height.toStringAsFixed(0)} cm',
                    style: const TextStyle(
                      color: Color(0xFF737373),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  progressDeltaStr,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeightCol('Inicial', '${profile.initialWeight.toStringAsFixed(1)} kg', const Color(0xFF737373)),
              _buildWeightDivider(),
              _buildWeightCol('Actual', '${profile.currentWeight.toStringAsFixed(1)} kg', const Color(0xFF171717)),
              _buildWeightDivider(),
              _buildWeightCol('Meta', '${profile.targetWeight.toStringAsFixed(1)} kg', const Color(0xFF171717)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso de tu meta',
                style: TextStyle(color: const Color(0xFF404040), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(profile.progressPercentage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.fastOutSlowIn,
                height: 10,
                width: MediaQuery.of(context).size.width * 0.75 * profile.progressPercentage, // approximated relative width
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.black, Color(0xFF737373)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFA3A3A3), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isLosing 
                      ? 'Te faltan ${remainingWeight.toStringAsFixed(1)} kg para alcanzar tu peso meta de ${profile.targetWeight.toStringAsFixed(0)} kg.'
                      : 'Llevas un incremento positivo hacia tu peso meta de ${profile.targetWeight.toStringAsFixed(0)} kg.',
                  style: const TextStyle(color: Color(0xFF737373), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecordsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_chart_rounded, size: 18),
              label: const Text('Ver Historial y Registrar Medidas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCol(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFA3A3A3),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWeightDivider() {
    return Container(
      height: 24,
      width: 1,
      color: const Color(0xFFE5E5E5),
    );
  }
}
