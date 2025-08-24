import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../providers/data_management_provider.dart';
import '../../widgets/common/accessible_button.dart';
import '../../widgets/common/loading_button.dart';

class DataExportPage extends ConsumerStatefulWidget {
  final String userId;

  const DataExportPage({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  @override
  void initState() {
    super.initState();
    // Load data size info when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataManagementProvider.notifier).loadDataSizeInfo(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(dataManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataExport),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.download_outlined,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.exportYourData,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.exportDataDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Data size information
            if (state.dataSizeInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.yourDataSummary,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDataSummaryRow(
                        l10n.totalRecords,
                        state.dataSizeInfo!.totalRecords.toString(),
                        Icons.storage_outlined,
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildDataSummaryRow(
                        l10n.approximateSize,
                        state.dataSizeInfo!.formattedSize,
                        Icons.folder_outlined,
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
                      _buildDataBreakdownRow(
                        l10n.workoutSessions,
                        state.dataSizeInfo!.workoutSessions.toString(),
                        theme,
                      ),
                      _buildDataBreakdownRow(
                        l10n.personalRecords,
                        state.dataSizeInfo!.prRecords.toString(),
                        theme,
                      ),
                      _buildDataBreakdownRow(
                        l10n.workoutTemplates,
                        state.dataSizeInfo!.templates.toString(),
                        theme,
                      ),
                      _buildDataBreakdownRow(
                        l10n.notifications,
                        state.dataSizeInfo!.notifications.toString(),
                        theme,
                      ),
                      _buildDataBreakdownRow(
                        l10n.streakRecords,
                        state.dataSizeInfo!.streakRecords.toString(),
                        theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Export progress
            if (state.isExporting) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.exportingData,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: state.exportProgress,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.exportStatus ?? l10n.processing,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(state.exportProgress * 100).toInt()}%',
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

            // Export result
            if (state.lastExportResult != null && !state.isExporting) ...[
              Card(
                color: state.lastExportResult!.success
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
                            state.lastExportResult!.success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: state.lastExportResult!.success
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.lastExportResult!.success
                                ? l10n.exportCompleted
                                : l10n.exportFailed,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: state.lastExportResult!.success
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                      if (state.lastExportResult!.success) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${l10n.recordsExported}: ${state.lastExportResult!.recordCount}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '${l10n.fileSize}: ${state.lastExportResult!.formattedFileSize}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AccessibleButton(
                          onPressed: () {
                            ref.read(dataManagementProvider.notifier).shareExportFile();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.share_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(l10n.shareFile),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          state.lastExportResult!.error ?? l10n.unknownError,
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
            if (state.error != null && !state.isExporting) ...[
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

            // Export button
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed: state.isExporting
                    ? null
                    : () {
                        ref.read(dataManagementProvider.notifier).exportUserData(widget.userId);
                      },
                isLoading: state.isExporting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_outlined),
                    const SizedBox(width: 8),
                    Text(
                      state.isExporting ? l10n.exporting : l10n.startExport,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Information card
            Card(
              color: theme.colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.exportInformation,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.exportInformationDetails,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSummaryRow(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
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
}