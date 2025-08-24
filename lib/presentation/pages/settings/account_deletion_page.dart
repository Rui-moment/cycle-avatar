import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../providers/data_management_provider.dart';
import '../../widgets/common/accessible_button.dart';
import '../../widgets/common/loading_button.dart';

class AccountDeletionPage extends ConsumerStatefulWidget {
  final String userId;

  const AccountDeletionPage({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  bool _showConfirmation = false;
  bool _understandConsequences = false;
  bool _confirmDeletion = false;
  DeletionType _selectedDeletionType = DeletionType.local;

  @override
  void initState() {
    super.initState();
    // Load deletion info when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataManagementProvider.notifier).loadDeletionInfo(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(dataManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountDeletion),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning header
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          color: theme.colorScheme.onErrorContainer,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.dangerZone,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.accountDeletionWarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Deletion type selection
            if (!_showConfirmation) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectDeletionType,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Local data deletion option
                      RadioListTile<DeletionType>(
                        title: Text(l10n.deleteLocalDataOnly),
                        subtitle: Text(l10n.deleteLocalDataDescription),
                        value: DeletionType.local,
                        groupValue: _selectedDeletionType,
                        onChanged: (value) {
                          setState(() {
                            _selectedDeletionType = value!;
                          });
                        },
                      ),
                      
                      // Complete account deletion option
                      RadioListTile<DeletionType>(
                        title: Text(l10n.deleteCompleteAccount),
                        subtitle: Text(l10n.deleteCompleteAccountDescription),
                        value: DeletionType.complete,
                        groupValue: _selectedDeletionType,
                        onChanged: (value) {
                          setState(() {
                            _selectedDeletionType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Data to be deleted information
              if (state.deletionInfo != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dataToBeDeleted,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDeletionSummaryRow(
                          l10n.totalRecords,
                          state.deletionInfo!.totalRecords.toString(),
                          Icons.storage_outlined,
                          theme,
                        ),
                        const SizedBox(height: 8),
                        _buildDeletionSummaryRow(
                          l10n.estimatedTime,
                          state.deletionInfo!.formattedEstimatedTime,
                          Icons.schedule_outlined,
                          theme,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          l10n.dataBreakdown,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...state.deletionInfo!.details.entries.map((entry) =>
                          _buildDataBreakdownRow(entry.key, entry.value.toString(), theme),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Proceed to confirmation button
              SizedBox(
                width: double.infinity,
                child: AccessibleButton(
                  onPressed: () {
                    setState(() {
                      _showConfirmation = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_forever_outlined),
                      const SizedBox(width: 8),
                      Text(
                        l10n.proceedToDeletion,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Confirmation section
            if (_showConfirmation && !state.isDeleting) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.confirmDeletion,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Consequences understanding checkbox
                      CheckboxListTile(
                        title: Text(
                          l10n.understandConsequences,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        subtitle: Text(
                          l10n.understandConsequencesDetails,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                        value: _understandConsequences,
                        onChanged: (value) {
                          setState(() {
                            _understandConsequences = value ?? false;
                          });
                        },
                        activeColor: theme.colorScheme.error,
                        checkColor: theme.colorScheme.onError,
                      ),
                      
                      // Final confirmation checkbox
                      CheckboxListTile(
                        title: Text(
                          l10n.confirmDeletionFinal,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: _confirmDeletion,
                        onChanged: _understandConsequences
                            ? (value) {
                                setState(() {
                                  _confirmDeletion = value ?? false;
                                });
                              }
                            : null,
                        activeColor: theme.colorScheme.error,
                        checkColor: theme.colorScheme.onError,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: AccessibleButton(
                              onPressed: () {
                                setState(() {
                                  _showConfirmation = false;
                                  _understandConsequences = false;
                                  _confirmDeletion = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.onErrorContainer,
                                side: BorderSide(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: LoadingButton(
                              onPressed: _understandConsequences && _confirmDeletion
                                  ? () => _performDeletion()
                                  : null,
                              isLoading: false,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                              child: Text(l10n.deleteNow),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Deletion progress
            if (state.isDeleting) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deletingData,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: state.deletionProgress,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.deletionStatus ?? l10n.processing,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(state.deletionProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Deletion result
            if (state.lastDeletionResult != null && !state.isDeleting) ...[
              Card(
                color: state.lastDeletionResult!.success
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            state.lastDeletionResult!.success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: state.lastDeletionResult!.success
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.lastDeletionResult!.success
                                ? l10n.deletionCompleted
                                : l10n.deletionFailed,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: state.lastDeletionResult!.success
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                      if (state.lastDeletionResult!.success) ...[
                        const SizedBox(height: 12),
                        if (state.lastDeletionResult!.deletedRecords != null &&
                            state.lastDeletionResult!.deletedRecords! > 0)
                          Text(
                            '${l10n.recordsDeleted}: ${state.lastDeletionResult!.deletedRecords}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        if (state.lastDeletionResult!.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.lastDeletionResult!.message!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          state.lastDeletionResult!.error ?? l10n.unknownError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Error display
            if (state.error != null && !state.isDeleting) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ref.read(dataManagementProvider.notifier).clearError();
                        },
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeletionSummaryRow(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDataBreakdownRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            '• $label',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _performDeletion() {
    switch (_selectedDeletionType) {
      case DeletionType.local:
        ref.read(dataManagementProvider.notifier).deleteLocalUserData(widget.userId);
        break;
      case DeletionType.complete:
        ref.read(dataManagementProvider.notifier).deleteCompleteAccount(widget.userId);
        break;
      case DeletionType.server:
        // This shouldn't happen with current UI, but handle it just in case
        ref.read(dataManagementProvider.notifier).deleteCompleteAccount(widget.userId);
        break;
    }
  }
}