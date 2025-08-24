import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/localization_service.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageSettings),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.appLanguage,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.languageDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Language options
          Expanded(
            child: ListView(
              children: [
                _buildLanguageOption(
                  context: context,
                  ref: ref,
                  languageCode: 'en',
                  languageName: l10n.english,
                  nativeName: 'English',
                  isSelected: currentLocale.languageCode == 'en',
                  onTap: () => _changeLanguage(context, ref, 'en'),
                ),
                _buildLanguageOption(
                  context: context,
                  ref: ref,
                  languageCode: 'ja',
                  languageName: l10n.japanese,
                  nativeName: '日本語',
                  isSelected: currentLocale.languageCode == 'ja',
                  onTap: () => _changeLanguage(context, ref, 'ja'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String languageCode,
    required String languageName,
    required String nativeName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected 
              ? Theme.of(context).primaryColor
              : Theme.of(context).disabledColor,
          child: Text(
            languageCode.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          languageName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          nativeName,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              )
            : const Icon(Icons.radio_button_unchecked),
        onTap: onTap,
      ),
    );
  }
  
  Future<void> _changeLanguage(
    BuildContext context, 
    WidgetRef ref, 
    String languageCode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final localeNotifier = ref.read(localeProvider.notifier);
    
    try {
      await localeNotifier.changeLanguage(languageCode);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.languageChanged),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.languageChangeError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}