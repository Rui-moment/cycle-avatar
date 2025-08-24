import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/localization_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Language Settings Section
          _buildSectionHeader(context, l10n.language),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.languageSettings),
              subtitle: Text(_getLanguageDisplayName(currentLocale.languageCode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/language'),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Notifications Section
          _buildSectionHeader(context, l10n.notificationSettings),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(l10n.notificationSettings),
              subtitle: Text('${l10n.recoveryNotifications}, ${l10n.prNotifications}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Accessibility Section
          _buildSectionHeader(context, l10n.accessibilitySettings),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.accessibility),
              title: Text(l10n.accessibilitySettings),
              subtitle: Text('${l10n.textSize}, ${l10n.hapticFeedback}, ${l10n.voiceInput}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/accessibility'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // App Info Section
          _buildSectionHeader(context, 'App Info'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0+1'),
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to help page
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      default:
        return languageCode.toUpperCase();
    }
  }
}