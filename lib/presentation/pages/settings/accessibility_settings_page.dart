import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/accessibility_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/common/accessible_button.dart';

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessibilitySettings = ref.watch(accessibilitySettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.accessibilitySettings ?? 'Accessibility Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Screen Reader Section
          _buildSectionHeader(
            context,
            l10n?.screenReaderSupport ?? 'Screen Reader Support',
            Icons.accessibility,
          ),
          _buildInfoCard(
            context,
            l10n?.screenReaderStatus ?? 'Screen Reader Status',
            accessibilitySettings.screenReaderEnabled
                ? (l10n?.enabled ?? 'Enabled')
                : (l10n?.disabled ?? 'Disabled'),
            accessibilitySettings.screenReaderEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          AccessibleButton(
            onPressed: () {
              ref.read(accessibilitySettingsProvider.notifier)
                  .refreshAccessibilitySettings();
            },
            semanticLabel: l10n?.refreshAccessibilitySettings ?? 'Refresh accessibility settings',
            child: Text(l10n?.refresh ?? 'Refresh'),
          ),
          
          const SizedBox(height: 24),
          
          // Text Size Section
          _buildSectionHeader(
            context,
            l10n?.textSize ?? 'Text Size',
            Icons.text_fields,
          ),
          _buildTextSizeSlider(context, ref, accessibilitySettings),
          
          const SizedBox(height: 24),
          
          // High Contrast Section
          _buildSectionHeader(
            context,
            l10n?.highContrast ?? 'High Contrast',
            Icons.contrast,
          ),
          _buildInfoCard(
            context,
            l10n?.highContrastStatus ?? 'High Contrast Status',
            accessibilitySettings.highContrastEnabled
                ? (l10n?.enabled ?? 'Enabled')
                : (l10n?.disabled ?? 'Disabled'),
            accessibilitySettings.highContrastEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          
          const SizedBox(height: 24),
          
          // Haptic Feedback Section
          _buildSectionHeader(
            context,
            l10n?.hapticFeedback ?? 'Haptic Feedback',
            Icons.vibration,
          ),
          SwitchListTile(
            title: Text(l10n?.enableHapticFeedback ?? 'Enable Haptic Feedback'),
            subtitle: Text(l10n?.hapticFeedbackDescription ?? 
                'Provides tactile feedback when interacting with buttons'),
            value: accessibilitySettings.hapticFeedbackEnabled,
            onChanged: (value) {
              ref.read(accessibilitySettingsProvider.notifier)
                  .toggleHapticFeedback();
              if (value) {
                AccessibilityService.provideMediumHapticFeedback();
              }
            },
          ),
          
          const SizedBox(height: 24),
          
          // Voice Input Section
          _buildSectionHeader(
            context,
            l10n?.voiceInput ?? 'Voice Input',
            Icons.mic,
          ),
          _buildInfoCard(
            context,
            l10n?.voiceInputSupport ?? 'Voice Input Support',
            l10n?.voiceInputDescription ?? 
                'Voice input is available for weight and rep entry in workout logging',
            theme.colorScheme.primary,
          ),
          
          const SizedBox(height: 24),
          
          // Test Accessibility Features
          _buildSectionHeader(
            context,
            l10n?.testFeatures ?? 'Test Features',
            Icons.science,
          ),
          AccessibleButton(
            onPressed: () => _testHapticFeedback(),
            semanticLabel: l10n?.testHapticFeedback ?? 'Test haptic feedback',
            child: Text(l10n?.testHapticFeedback ?? 'Test Haptic Feedback'),
          ),
          const SizedBox(height: 8),
          AccessibleButton(
            onPressed: () => _showAccessibilityDemo(context),
            semanticLabel: l10n?.showAccessibilityDemo ?? 'Show accessibility demo',
            child: Text(l10n?.accessibilityDemo ?? 'Accessibility Demo'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String subtitle, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.info, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildTextSizeSlider(BuildContext context, WidgetRef ref, AccessibilitySettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Text Scale: ${(settings.textScaleFactor * 100).round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: settings.textScaleFactor,
              min: 1.0,
              max: 2.0,
              divisions: 10,
              label: '${(settings.textScaleFactor * 100).round()}%',
              onChanged: (value) {
                ref.read(accessibilitySettingsProvider.notifier)
                    .updateTextScaleFactor(value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Sample text at current size',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _testHapticFeedback() {
    AccessibilityService.provideLightHapticFeedback();
    Future.delayed(const Duration(milliseconds: 200), () {
      AccessibilityService.provideMediumHapticFeedback();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      AccessibilityService.provideHeavyHapticFeedback();
    });
  }

  void _showAccessibilityDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accessibility Features'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✓ Screen reader support with semantic labels'),
              SizedBox(height: 8),
              Text('✓ Adjustable text size (100% - 200%)'),
              SizedBox(height: 8),
              Text('✓ High contrast mode support'),
              SizedBox(height: 8),
              Text('✓ Haptic feedback for interactions'),
              SizedBox(height: 8),
              Text('✓ Voice input for workout data'),
              SizedBox(height: 8),
              Text('✓ Keyboard navigation support'),
              SizedBox(height: 8),
              Text('✓ Focus management and indicators'),
            ],
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
}