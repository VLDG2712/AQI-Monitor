// lib/widgets/sensor_tile.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class SensorTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? iconText;
  final String? emoji;

  const SensorTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.iconText,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 20))
          else if (iconText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                iconText!,
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.text2,
            ),
          ),
        ],
      ),
    );
  }
}
