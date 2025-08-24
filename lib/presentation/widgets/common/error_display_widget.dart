import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_error.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/l10n/app_localizations.dart';

/// Widget for displaying user-friendly error messages
class ErrorDisplayWidget extends ConsumerWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDetails;
  final EdgeInsets padding;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showDetails = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: padding,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getErrorIcon(),
                  color: _getErrorColor(theme),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getErrorTitle(l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _getErrorColor(theme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.toUserMessage(),
              style: theme.textTheme.bodyMedium,
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: Text(
                  'Technical Details',
                  style: theme.textTheme.bodySmall,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Error Code: ${error.code}'),
                        Text('Timestamp: ${error.timestamp}'),
                        if (error.context != null)
                          Text('Context: ${error.context}'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (onRetry != null || error.canAutoRecover) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (error.canAutoRecover)
                    TextButton.icon(
                      onPressed: () => _attemptAutoRecovery(context),
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(l10n.autoRecover ?? 'Auto Recover'),
                    ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (error is NetworkError) {
      return Icons.wifi_off;
    } else if (error is DatabaseError) {
      return Icons.storage;
    } else if (error is ValidationError) {
      return Icons.warning;
    } else if (error is SyncError) {
      return Icons.sync_problem;
    } else if (error is AuthError) {
      return Icons.lock;
    } else {
      return Icons.error_outline;
    }
  }

  Color _getErrorColor(ThemeData theme) {
    if (error is ValidationError) {
      return theme.colorScheme.secondary;
    } else if (error is NetworkError || error is SyncError) {
      return Colors.orange;
    } else {
      return theme.colorScheme.error;
    }
  }

  String _getErrorTitle(AppLocalizations l10n) {
    if (error is NetworkError) {
      return 'Connection Issue';
    } else if (error is DatabaseError) {
      return 'Data Issue';
    } else if (error is ValidationError) {
      return 'Input Error';
    } else if (error is SyncError) {
      return 'Sync Issue';
    } else if (error is AuthError) {
      return 'Authentication Issue';
    } else if (error is BusinessLogicError) {
      return 'Temporary Issue';
    } else {
      return 'Error';
    }
  }

  Future<void> _attemptAutoRecovery(BuildContext context) async {
    try {
      await error.recover();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue resolved automatically'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      onDismiss?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto recovery failed. Please try manual retry.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

/// Snackbar for quick error notifications
class ErrorSnackBar extends SnackBar {
  ErrorSnackBar({
    super.key,
    required AppError error,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) : super(
          content: Row(
            children: [
              Icon(
                _getErrorIcon(error),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.toUserMessage(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: _getErrorColor(error),
          duration: duration,
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        );

  static IconData _getErrorIcon(AppError error) {
    if (error is NetworkError) {
      return Icons.wifi_off;
    } else if (error is ValidationError) {
      return Icons.warning;
    } else if (error is SyncError) {
      return Icons.sync_problem;
    } else {
      return Icons.error_outline;
    }
  }

  static Color _getErrorColor(AppError error) {
    if (error is ValidationError) {
      return Colors.orange;
    } else if (error is NetworkError || error is SyncError) {
      return Colors.blue;
    } else {
      return Colors.red;
    }
  }
}

/// Dialog for critical errors
class ErrorDialog extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        _getErrorIcon(),
        color: theme.colorScheme.error,
        size: 32,
      ),
      title: Text(_getErrorTitle()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error.toUserMessage()),
          if (error.canAutoRecover) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This issue can be resolved automatically',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: Text(l10n.dismiss ?? 'Dismiss'),
          ),
        if (error.canAutoRecover)
          TextButton.icon(
            onPressed: () => _attemptAutoRecovery(context),
            icon: const Icon(Icons.auto_fix_high),
            label: Text(l10n.autoRecover ?? 'Auto Fix'),
          ),
        if (onRetry != null)
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
      ],
    );
  }

  IconData _getErrorIcon() {
    if (error is NetworkError) {
      return Icons.wifi_off;
    } else if (error is DatabaseError) {
      return Icons.storage;
    } else if (error is AuthError) {
      return Icons.lock;
    } else {
      return Icons.error_outline;
    }
  }

  String _getErrorTitle() {
    if (error is NetworkError) {
      return 'Connection Problem';
    } else if (error is DatabaseError) {
      return 'Data Problem';
    } else if (error is AuthError) {
      return 'Authentication Problem';
    } else {
      return 'Error Occurred';
    }
  }

  Future<void> _attemptAutoRecovery(BuildContext context) async {
    try {
      await error.recover();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto recovery failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> show(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        error: error,
        onRetry: onRetry,
        onDismiss: onDismiss,
      ),
    );
  }
}

/// Provider for global error state
final globalErrorProvider = StateNotifierProvider<GlobalErrorNotifier, AppError?>((ref) {
  return GlobalErrorNotifier();
});

class GlobalErrorNotifier extends StateNotifier<AppError?> {
  GlobalErrorNotifier() : super(null);

  void showError(AppError error) {
    state = error;
  }

  void clearError() {
    state = null;
  }
}

/// Widget that listens for global errors and displays them
class GlobalErrorListener extends ConsumerWidget {
  final Widget child;

  const GlobalErrorListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(globalErrorProvider);

    // Show error snackbar when error occurs
    ref.listen<AppError?>(globalErrorProvider, (previous, next) {
      if (next != null && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              ErrorSnackBar(
                error: next,
                onRetry: next.canAutoRecover
                    ? () async {
                        try {
                          await next.recover();
                          ref.read(globalErrorProvider.notifier).clearError();
                        } catch (e) {
                          // Recovery failed, keep error visible
                        }
                      }
                    : null,
              ),
            );
          }
        });
      }
    });

    return child;
  }
}