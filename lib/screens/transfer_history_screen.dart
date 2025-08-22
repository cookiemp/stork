import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/transfer_history.dart';
import '../services/transfer_history_service.dart';

class TransferHistoryScreen extends StatefulWidget {
  final TransferHistoryService historyService;

  const TransferHistoryScreen({
    super.key,
    required this.historyService,
  });

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<TransferRecord> _filteredHistory = [];
  TransferStatus? _statusFilter;
  TransferDirection? _directionFilter;
  bool _showStats = false;
  late AnimationController _statsAnimationController;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _filteredHistory = widget.historyService.history;
    widget.historyService.addListener(_updateHistory);
    
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _statsAnimation = CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.historyService.removeListener(_updateHistory);
    _statsAnimationController.dispose();
    super.dispose();
  }

  void _updateHistory() {
    setState(() {
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<TransferRecord> filtered = widget.historyService.history;
    
    // Apply search filter
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      filtered = widget.historyService.searchHistory(query);
    }
    
    // Apply status filter
    if (_statusFilter != null) {
      filtered = filtered.where((record) => record.status == _statusFilter).toList();
    }
    
    // Apply direction filter
    if (_directionFilter != null) {
      filtered = filtered.where((record) => record.direction == _directionFilter).toList();
    }
    
    _filteredHistory = filtered;
  }

  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
    });
    if (_showStats) {
      _statsAnimationController.forward();
    } else {
      _statsAnimationController.reverse();
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Transfer History'),
        content: const Text(
          'Are you sure you want to clear all transfer history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await widget.historyService.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer history cleared')),
        );
      }
    }
  }

  Future<void> _openFile(TransferRecord record) async {
    final fileExists = await widget.historyService.doesFileExist(record.filePath);
    
    if (!fileExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File no longer exists: ${record.fileName}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // On Windows, use 'start' command to open file with default application
      if (Platform.isWindows) {
        await Process.run('start', [record.filePath], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [record.filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [record.filePath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File path copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.historyService.getStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _toggleStats,
            tooltip: 'Show Statistics',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Panel
          AnimatedBuilder(
            animation: _statsAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _statsAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: _StatisticsPanel(stats: stats),
                ),
              );
            },
          ),
          
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search transfers...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Filter Chips
                Row(
                  children: [
                    const Text('Filters: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          // Status Filter
                          ChoiceChip(
                            label: Text(_statusFilter?.name ?? 'All Status'),
                            selected: _statusFilter != null,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _showStatusFilterDialog();
                                } else {
                                  _statusFilter = null;
                                  _applyFilters();
                                }
                              });
                            },
                          ),
                          
                          // Direction Filter
                          ChoiceChip(
                            label: Text(_directionFilter?.name ?? 'All Direction'),
                            selected: _directionFilter != null,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _showDirectionFilterDialog();
                                } else {
                                  _directionFilter = null;
                                  _applyFilters();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Transfer List
          Expanded(
            child: _filteredHistory.isEmpty
                ? _EmptyHistoryState(
                    hasFilters: _searchController.text.isNotEmpty || 
                                _statusFilter != null || 
                                _directionFilter != null,
                    onClearFilters: () {
                      setState(() {
                        _searchController.clear();
                        _statusFilter = null;
                        _directionFilter = null;
                        _applyFilters();
                      });
                    },
                  )
                : ListView.builder(
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      final record = _filteredHistory[index];
                      return _TransferRecordCard(
                        record: record,
                        onTap: () => _showRecordDetails(record),
                        onOpenFile: () => _openFile(record),
                        onCopyPath: () => _copyPath(record.filePath),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TransferStatus.values.map((status) {
            return RadioListTile<TransferStatus>(
              title: Text(status.name),
              value: status,
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = value;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDirectionFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Direction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TransferDirection.values.map((direction) {
            return RadioListTile<TransferDirection>(
              title: Text(direction.name),
              value: direction,
              groupValue: _directionFilter,
              onChanged: (value) {
                setState(() {
                  _directionFilter = value;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRecordDetails(TransferRecord record) {
    showDialog(
      context: context,
      builder: (context) => _TransferRecordDialog(record: record),
    );
  }
}

class _StatisticsPanel extends StatelessWidget {
  final TransferStatistics stats;

  const _StatisticsPanel({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer Statistics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Transfers',
                value: stats.totalTransfers.toString(),
                icon: Icons.swap_horiz,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Success Rate',
                value: '${stats.successRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Size',
                value: stats.formattedTotalBytes,
                icon: Icons.storage,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Avg Speed',
                value: stats.formattedAverageSpeed,
                icon: Icons.speed,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRecordCard extends StatelessWidget {
  final TransferRecord record;
  final VoidCallback onTap;
  final VoidCallback onOpenFile;
  final VoidCallback onCopyPath;

  const _TransferRecordCard({
    required this.record,
    required this.onTap,
    required this.onOpenFile,
    required this.onCopyPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(record.directionIcon, size: 20),
            Icon(record.statusIcon, 
                 color: record.statusColor, 
                 size: 16),
          ],
        ),
        title: Text(
          record.fileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${record.targetName} (${record.targetHost}:${record.targetPort})'),
            Row(
              children: [
                Text(record.formattedFileSize),
                const Text(' • '),
                Text(record.formattedDuration),
                const Text(' • '),
                Text(record.formattedSpeed),
              ],
            ),
            Text(
              _formatDateTime(record.startTime),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                onOpenFile();
                break;
              case 'copy':
                onCopyPath();
                break;
              case 'details':
                onTap();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('Details'),
                ],
              ),
            ),
            if (record.direction == TransferDirection.received)
              const PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new),
                    SizedBox(width: 8),
                    Text('Open File'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('Copy Path'),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onClearFilters;

  const _EmptyHistoryState({
    required this.hasFilters,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.history,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No transfers match your filters' : 'No transfer history',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters 
                ? 'Try adjusting your search or filters'
                : 'Your completed transfers will appear here',
            style: const TextStyle(color: Colors.grey),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferRecordDialog extends StatelessWidget {
  final TransferRecord record;

  const _TransferRecordDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Transfer Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow('File Name', record.fileName),
            _DetailRow('File Size', record.formattedFileSize),
            _DetailRow('Target', '${record.targetName} (${record.targetHost}:${record.targetPort})'),
            _DetailRow('Direction', record.direction.name),
            _DetailRow('Status', record.status.name),
            _DetailRow('Type', record.type.name),
            _DetailRow('Start Time', record.startTime.toString()),
            if (record.endTime != null)
              _DetailRow('End Time', record.endTime.toString()),
            _DetailRow('Duration', record.formattedDuration),
            _DetailRow('Average Speed', record.formattedSpeed),
            if (record.errorMessage != null)
              _DetailRow('Error', record.errorMessage!),
            _DetailRow('File Path', record.filePath),
            if (record.batchId != null)
              _DetailRow('Batch ID', record.batchId!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
