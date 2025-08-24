import 'package:flutter/material.dart';

class RPEPicker extends StatelessWidget {
  final int selectedRPE;
  final Function(int) onRPEChanged;

  const RPEPicker({
    super.key,
    required this.selectedRPE,
    required this.onRPEChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'RPE (Rate of Perceived Exertion)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _getRPEDescription(selectedRPE),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Selected RPE display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'RPE $selectedRPE',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getRPEColor(selectedRPE),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _getRPEIcon(selectedRPE),
                    color: _getRPEColor(selectedRPE),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getRPEDescription(selectedRPE),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // RPE slider
              Slider(
                value: selectedRPE.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: selectedRPE.toString(),
                onChanged: (value) => onRPEChanged(value.round()),
              ),
              
              // Quick RPE buttons
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickRPEButton(context, 6, 'Easy'),
                  _buildQuickRPEButton(context, 7, 'Moderate'),
                  _buildQuickRPEButton(context, 8, 'Hard'),
                  _buildQuickRPEButton(context, 9, 'Very Hard'),
                  _buildQuickRPEButton(context, 10, 'Max'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRPEButton(BuildContext context, int rpe, String label) {
    final isSelected = selectedRPE == rpe;
    
    return GestureDetector(
      onTap: () => onRPEChanged(rpe),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _getRPEColor(rpe) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getRPEColor(rpe),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rpe.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : _getRPEColor(rpe),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : _getRPEColor(rpe),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRPEColor(int rpe) {
    if (rpe <= 4) return Colors.green;
    if (rpe <= 6) return Colors.lightGreen;
    if (rpe <= 7) return Colors.yellow.shade700;
    if (rpe <= 8) return Colors.orange;
    if (rpe <= 9) return Colors.red;
    return Colors.red.shade900;
  }

  IconData _getRPEIcon(int rpe) {
    if (rpe <= 4) return Icons.sentiment_very_satisfied;
    if (rpe <= 6) return Icons.sentiment_satisfied;
    if (rpe <= 7) return Icons.sentiment_neutral;
    if (rpe <= 8) return Icons.sentiment_dissatisfied;
    if (rpe <= 9) return Icons.sentiment_very_dissatisfied;
    return Icons.warning;
  }

  String _getRPEDescription(int rpe) {
    switch (rpe) {
      case 1:
      case 2:
        return 'Very easy - could do many more reps';
      case 3:
      case 4:
        return 'Easy - could do several more reps';
      case 5:
      case 6:
        return 'Moderate - could do a few more reps';
      case 7:
        return 'Hard - could do 2-3 more reps';
      case 8:
        return 'Very hard - could do 1-2 more reps';
      case 9:
        return 'Extremely hard - could do 1 more rep';
      case 10:
        return 'Maximum effort - could not do another rep';
      default:
        return 'Select your effort level';
    }
  }
}