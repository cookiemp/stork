import 'package:flutter/material.dart';
import '../services/batch_transfer_service.dart';
import '../services/animation_service.dart';

/// Dialog showing progress of a batch file transfer
class BatchTransferProgressDialog extends StatefulWidget {
  final String transferId;
  final BatchTransferService batchService;

  const BatchTransferProgressDialog({
    super.key,
    required this.transferId,
    required this.batchService,
  });

  @override
  State<BatchTransferProgressDialog> createState() => _BatchTransferProgressDialogState();
}

class _BatchTransferProgressDialogState extends State<BatchTransferProgressDialog> {
  late Stream<BatchTransfer> _transferStream;
  BatchTransfer? _currentTransfer;

  @override
  void initState() {
    super.initState();
    _transferStream = widget.batchService.getTransferStream(widget.transferId) ?? const Stream.empty();
    
    // Also get initial state
    _currentTransfer = widget.batchService.getTransfer(widget.transferId);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<BatchTransfer>(
          stream: _transferStream,
          initialData: _currentTransfer,
          builder: (context, snapshot) {
            final transfer = snapshot.data;
            if (transfer == null) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('Transfer not found'),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(transfer),
                const SizedBox(height: 16),
                _buildOverallProgress(transfer),
                const SizedBox(height: 16),
                _buildFileList(transfer),
                const SizedBox(height: 16),
                _buildActions(transfer),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BatchTransfer transfer) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          _getStatusIcon(transfer.status),
          color: _getStatusColor(transfer.status),
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Batch Transfer',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'To ${transfer.targetPeer.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        if (transfer.status == BatchTransferStatus.transferring)
          IconButton(
            onPressed: () => _cancelTransfer(transfer),
            icon: const Icon(Icons.stop),
            tooltip: 'Cancel transfer',
          )
        else if (transfer.isCompleted)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
      ],
    );
  }

  Widget _buildOverallProgress(BatchTransfer transfer) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${transfer.completedFiles}/${transfer.totalFiles} files',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatStatus(transfer),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getStatusColor(transfer.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressIndicator(
            progress: transfer.overallProgress,
            strokeWidth: 8.0,
            backgroundColor: theme.colorScheme.surfaceVariant,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(transfer.overallProgress * 100).toInt()}% complete',
                style: theme.textTheme.bodySmall,
              ),
              if (transfer.elapsedTime != null)
                Text(
                  _formatDuration(transfer.elapsedTime!),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BatchTransfer transfer) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: transfer.files.length,
        itemBuilder: (context, index) {
          final file = transfer.files[index];
          return _buildFileItem(file, theme);
        },
      ),
    );
  }

  Widget _buildFileItem(BatchFile file, ThemeData theme) {
    return ListTile(
      leading: Icon(
        _getFileStatusIcon(file.status),
        color: _getFileStatusColor(file.status),
      ),
      title: Text(
        file.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.formattedSize),
          if (file.status == BatchFileStatus.transferring) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: file.progress,
              backgroundColor: theme.colorScheme.surfaceVariant,
            ),
          ],
        ],
      ),
      trailing: file.status == BatchFileStatus.transferring
          ? Text('${(file.progress * 100).toInt()}%')
          : file.status == BatchFileStatus.failed
              ? IconButton(
                  onPressed: () => _retryFile(file),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Retry',
                )
              : null,
    );
  }

  Widget _buildActions(BatchTransfer transfer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (transfer.status == BatchTransferStatus.transferring)
          TextButton(
            onPressed: () => _cancelTransfer(transfer),
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        const SizedBox(width: 8),
        if (transfer.isCompleted && transfer.failedFiles > 0)
          ElevatedButton(
            onPressed: () => _retryFailedFiles(transfer),
            child: const Text('Retry Failed'),
          )
        else if (transfer.isCompleted)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
      ],
    );
  }

  IconData _getStatusIcon(BatchTransferStatus status) {
    switch (status) {
      case BatchTransferStatus.queued:
        return Icons.schedule;
      case BatchTransferStatus.transferring:
        return Icons.upload;
      case BatchTransferStatus.paused:
        return Icons.pause;
      case BatchTransferStatus.completed:
        return Icons.check_circle;
      case BatchTransferStatus.failed:
        return Icons.error;
      case BatchTransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(BatchTransferStatus status) {
    switch (status) {
      case BatchTransferStatus.queued:
        return Colors.orange;
      case BatchTransferStatus.transferring:
        return Colors.blue;
      case BatchTransferStatus.paused:
        return Colors.amber;
      case BatchTransferStatus.completed:
        return Colors.green;
      case BatchTransferStatus.failed:
        return Colors.red;
      case BatchTransferStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getFileStatusIcon(BatchFileStatus status) {
    switch (status) {
      case BatchFileStatus.queued:
        return Icons.schedule;
      case BatchFileStatus.transferring:
        return Icons.upload;
      case BatchFileStatus.completed:
        return Icons.check_circle;
      case BatchFileStatus.failed:
        return Icons.error;
      case BatchFileStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getFileStatusColor(BatchFileStatus status) {
    switch (status) {
      case BatchFileStatus.queued:
        return Colors.orange;
      case BatchFileStatus.transferring:
        return Colors.blue;
      case BatchFileStatus.completed:
        return Colors.green;
      case BatchFileStatus.failed:
        return Colors.red;
      case BatchFileStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatStatus(BatchTransfer transfer) {
    switch (transfer.status) {
      case BatchTransferStatus.queued:
        return 'Queued';
      case BatchTransferStatus.transferring:
        return 'Transferring';
      case BatchTransferStatus.paused:
        return 'Paused';
      case BatchTransferStatus.completed:
        if (transfer.failedFiles > 0) {
          return 'Completed with ${transfer.failedFiles} failed';
        }
        return 'Completed';
      case BatchTransferStatus.failed:
        return 'Failed';
      case BatchTransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  void _cancelTransfer(BatchTransfer transfer) {
    widget.batchService.cancelBatchTransfer(transfer.id);
  }

  void _retryFile(BatchFile file) {
    final transfer = widget.batchService.getTransfer(widget.transferId);
    if (transfer != null) {
      widget.batchService.retryFile(transfer.id, file.id);
    }
  }

  void _retryFailedFiles(BatchTransfer transfer) {
    for (final file in transfer.files) {
      if (file.status == BatchFileStatus.failed) {
        widget.batchService.retryFile(transfer.id, file.id);
      }
    }
  }
}

/// Helper function to show batch transfer progress dialog
void showBatchTransferProgress(
  BuildContext context, {
  required String transferId,
  required BatchTransferService batchService,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => BatchTransferProgressDialog(
      transferId: transferId,
      batchService: batchService,
    ),
  );
}
