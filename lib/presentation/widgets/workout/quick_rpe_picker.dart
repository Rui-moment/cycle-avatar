import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/constants.dart';

/// Quick RPE picker optimized for fast selection
class QuickRPEPicker extends StatelessWidget {
  final int selectedRPE;
  final Function(int) onRPEChanged;
  final bool showDescription;
  final bool compact;

  const QuickRPEPicker({
    super.key,
    required this.selectedRPE,
    required this.onRPEChanged,
    this.showDescription = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactPicker(context);
    }
    
    return _buildFullPicker(context);
  }

  Widget _buildCompactPicker(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Decrease button
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: selectedRPE > MIN_RPE ? () {
                HapticFeedback.selectionClick();
                onRPEChanged(selectedRPE - 1);
              } : null,
              icon: const Icon(Icons.remove, size: 18),
              padding: EdgeInsets.zero,
            ),
          ),
          
          // RPE display
          Expanded(
            child: GestureDetector(
              onTap: () => _showRPEDialog(context),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RPE $selectedRPE',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getRPEColor(selectedRPE),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _getRPEIcon(selectedRPE),
                      size: 16,
                      color: _getRPEColor(selectedRPE),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Increase button
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: selectedRPE < MAX_RPE ? () {
                HapticFeedback.selectionClick();
                onRPEChanged(selectedRPE + 1);
              } : null,
              icon: const Icon(Icons.add, size: 18),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPicker(BuildContext context) {
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
            GestureDetector(
              onTap: () => _showRPEDialog(context),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Quick selection buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(6, (index) {
            final rpe = index + 5; // RPE 5-10
            return _buildQuickRPEButton(context, rpe);
          }),
        ),
        
        if (showDescription) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getRPEIcon(selectedRPE),
                  color: _getRPEColor(selectedRPE),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getRPEDescription(selectedRPE),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickRPEButton(BuildContext context, int rpe) {
    final isSelected = selectedRPE == rpe;
    final color = _getRPEColor(rpe);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onRPEChanged(rpe);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rpe.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _getRPEIcon(rpe),
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
          ],
        ),
      ),
    );
  }

  void _showRPEDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RPE Scale'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 10,
            itemBuilder: (context, index) {
              final rpe = index + 1;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRPEColor(rpe),
                  child: Text(
                    rpe.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text('RPE $rpe'),
                subtitle: Text(_getRPEDescription(rpe)),
                trailing: selectedRPE == rpe ? const Icon(Icons.check) : null,
                onTap: () {
                  onRPEChanged(rpe);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
        return 'Moderate - could do 4-5 more reps';
      case 6:
        return 'Somewhat hard - could do 3-4 more reps';
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