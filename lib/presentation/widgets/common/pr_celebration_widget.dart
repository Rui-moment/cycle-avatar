import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/pr_record.dart';
import '../../../domain/entities/exercise.dart';

/// Widget that displays a celebration animation and details when a PR is achieved
class PRCelebrationWidget extends StatefulWidget {
  final PRRecord pr;
  final Exercise? exercise;
  final PRRecord? previousBest;
  final double improvementPercentage;
  final bool isSignificant;
  final VoidCallback? onDismiss;
  final VoidCallback? onShare;
  
  const PRCelebrationWidget({
    super.key,
    required this.pr,
    this.exercise,
    this.previousBest,
    required this.improvementPercentage,
    required this.isSignificant,
    this.onDismiss,
    this.onShare,
  });
  
  @override
  State<PRCelebrationWidget> createState() => _PRCelebrationWidgetState();
}

class _PRCelebrationWidgetState extends State<PRCelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _confettiController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _confettiAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _startCelebration();
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  void _startCelebration() async {
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Start animations with delays
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();
    _confettiController.forward();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Confetti animation
                      AnimatedBuilder(
                        animation: _confettiAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            height: 60,
                            child: Stack(
                              children: [
                                if (_confettiAnimation.value > 0)
                                  ..._buildConfettiParticles(),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // PR Icon and Title
                      Icon(
                        Icons.emoji_events,
                        size: 64,
                        color: _getPRColor(),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'New Personal Record!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getPRColor(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Exercise name
                      if (widget.exercise != null)
                        Text(
                          widget.exercise!.getLocalizedName('en'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      
                      // PR Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getPRColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildPRStat(
                                  'Weight',
                                  '${widget.pr.weight.toStringAsFixed(1)} kg',
                                  Icons.fitness_center,
                                ),
                                _buildPRStat(
                                  'Reps',
                                  '${widget.pr.reps}',
                                  Icons.repeat,
                                ),
                                _buildPRStat(
                                  'Est. 1RM',
                                  '${widget.pr.estimatedMax.toStringAsFixed(1)} kg',
                                  Icons.trending_up,
                                ),
                              ],
                            ),
                            
                            if (widget.improvementPercentage > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_upward,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${widget.improvementPercentage.toStringAsFixed(1)}%',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'improvement',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (widget.onShare != null)
                            OutlinedButton.icon(
                              onPressed: widget.onShare,
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                          FilledButton.icon(
                            onPressed: widget.onDismiss ?? () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check),
                            label: const Text('Awesome!'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPRStat(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: _getPRColor(),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
  
  Color _getPRColor() {
    if (widget.isSignificant) {
      return Colors.amber; // Gold for significant PRs
    } else {
      return Colors.blue; // Blue for regular PRs
    }
  }
  
  List<Widget> _buildConfettiParticles() {
    final particles = <Widget>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    
    for (int i = 0; i < 20; i++) {
      final delay = (i * 50) % 1000;
      final xOffset = ((random + i) % 300) - 150.0;
      final color = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
      ][(random + i) % 6];
      
      particles.add(
        Positioned(
          left: 150 + xOffset,
          top: 30 - (_confettiAnimation.value * 100),
          child: Transform.rotate(
            angle: (_confettiAnimation.value * 4) + (i * 0.5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    
    return particles;
  }
}

/// Shows a PR celebration dialog
Future<void> showPRCelebration(
  BuildContext context, {
  required PRRecord pr,
  Exercise? exercise,
  PRRecord? previousBest,
  required double improvementPercentage,
  required bool isSignificant,
  VoidCallback? onShare,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PRCelebrationWidget(
      pr: pr,
      exercise: exercise,
      previousBest: previousBest,
      improvementPercentage: improvementPercentage,
      isSignificant: isSignificant,
      onShare: onShare,
    ),
  );
}