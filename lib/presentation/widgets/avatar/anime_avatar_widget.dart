import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/recovery_state.dart';
import '../../../domain/entities/enums.dart';

/// Simple anime-style avatar that reflects muscle group recovery states
class AnimeAvatarWidget extends StatelessWidget {
  final Map<String, RecoveryState> recoveryStates;

  const AnimeAvatarWidget({super.key, required this.recoveryStates});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(180, 240),
        painter: _AnimeAvatarPainter(recoveryStates),
      ),
    );
  }
}

class _AnimeAvatarPainter extends CustomPainter {
  final Map<String, RecoveryState> recoveryStates;

  _AnimeAvatarPainter(this.recoveryStates);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final torsoColor = _colorForGroups(['chest', 'back']);
    final armColor = _colorForGroups(['biceps', 'triceps', 'shoulders']);
    final legColor = _colorForGroups(['quadriceps', 'hamstrings', 'calves']);

    // Head
    paint.color = Colors.pink.shade200;
    final headCenter = Offset(size.width / 2, size.height * 0.2);
    canvas.drawOval(
      Rect.fromCircle(center: headCenter, radius: size.width * 0.18),
      paint,
    );

    // Torso
    paint.color = torsoColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.45),
          width: size.width * 0.3,
          height: size.height * 0.35,
        ),
        const Radius.circular(16),
      ),
      paint,
    );

    // Arms
    paint.color = armColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.15, size.height * 0.45),
          width: size.width * 0.15,
          height: size.height * 0.3,
        ),
        const Radius.circular(8),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.85, size.height * 0.45),
          width: size.width * 0.15,
          height: size.height * 0.3,
        ),
        const Radius.circular(8),
      ),
      paint,
    );

    // Legs
    paint.color = legColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.4, size.height * 0.8),
          width: size.width * 0.15,
          height: size.height * 0.3,
        ),
        const Radius.circular(8),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.6, size.height * 0.8),
          width: size.width * 0.15,
          height: size.height * 0.3,
        ),
        const Radius.circular(8),
      ),
      paint,
    );

    // Facial features
    final eyePaint = Paint()..color = Colors.black;
    final eyeRadius = size.width * 0.03;
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.18),
      eyeRadius,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.18),
      eyeRadius,
      eyePaint,
    );

    final mouthPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final mouthWidth = size.width * 0.08;
    final mouthCenter = Offset(size.width / 2, size.height * 0.23);
    final avgRecovery = _averageRecovery();
    if (avgRecovery < 0.4) {
      // tired frown
      canvas.drawArc(
        Rect.fromCenter(
          center: mouthCenter,
          width: mouthWidth,
          height: mouthWidth / 2,
        ),
        0,
        math.pi,
        false,
        mouthPaint,
      );
    } else if (avgRecovery < 0.7) {
      // neutral
      canvas.drawLine(
        Offset(mouthCenter.dx - mouthWidth / 2, mouthCenter.dy),
        Offset(mouthCenter.dx + mouthWidth / 2, mouthCenter.dy),
        mouthPaint,
      );
    } else {
      // energetic smile
      canvas.drawArc(
        Rect.fromCenter(
          center: mouthCenter,
          width: mouthWidth,
          height: mouthWidth / 2,
        ),
        math.pi,
        math.pi,
        false,
        mouthPaint,
      );
    }
  }

  double _averageRecovery() {
    if (recoveryStates.isEmpty) return 1.0;
    final total = recoveryStates.values
        .map((s) => s.recoveryPercentage)
        .fold<double>(0, (a, b) => a + b);
    return total / recoveryStates.length;
  }

  Color _colorForGroups(List<String> groups) {
    final states = groups
        .map((g) => recoveryStates[g])
        .whereType<RecoveryState>()
        .toList();
    if (states.isEmpty) return Colors.grey.shade300;
    if (states.any((s) => s.readinessLevel == ReadinessLevel.fatigued)) {
      return Colors.red.shade300;
    }
    if (states.any((s) => s.readinessLevel == ReadinessLevel.warm)) {
      return Colors.orange.shade300;
    }
    return Colors.green.shade300;
  }

  @override
  bool shouldRepaint(covariant _AnimeAvatarPainter oldDelegate) {
    return oldDelegate.recoveryStates != recoveryStates;
  }
}

