import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/batch_transfer_service.dart';
import '../services/animation_service.dart';
import '../services/compression_service.dart';
import '../models/peer.dart';
import '../utils/file_helper.dart';

/// Enhanced file picker with multi-file selection and batch transfer support
class MultiFilePicker extends StatefulWidget {
  final Function(
    List<BatchFile> files, 
    Peer? targetPeer, {
    bool useCompression,
    CompressionLevel compressionLevel,
    bool smartCompression,
  }) onFilesSelected;
  final Peer? defaultPeer;
  final bool showPeerSelection;
  
  const MultiFilePicker({
    super.key,
    required this.onFilesSelected,
    this.defaultPeer,
    this.showPeerSelection = true,
  });

  @override
  State<MultiFilePicker> createState() => _MultiFilePickerState();
}

class _MultiFilePickerState extends State<MultiFilePicker> {
  final BatchTransferService _batchService = BatchTransferService();
  final CompressionService _compressionService = CompressionService();
  List<BatchFile> _selectedFiles = [];
  Peer? _selectedPeer;
  bool _isLoading = false;
  
  // Compression settings
  bool _useCompression = true;
  bool _smartCompression = true;
  CompressionLevel _compressionLevel = CompressionLevel.balanced;
  CompressionAnalysis? _compressionAnalysis;

  @override
  void initState() {
    super.initState();
    _selectedPeer = widget.defaultPeer;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 28,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Files to Send',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // File selection buttons
            _buildSelectionButtons(theme),
            
            const SizedBox(height: 16),
            
            // Selected files list
            Expanded(
              child: _buildFilesList(theme),
            ),
            
            const SizedBox(height: 16),
            
            // Compression settings (if files are selected)
            if (_selectedFiles.length > 1) ...[
              _buildCompressionSettings(theme),
              const SizedBox(height: 16),
            ],
            
            // Peer selection (if enabled)
            if (widget.showPeerSelection) ...[
              _buildPeerSelection(theme),
              const SizedBox(height: 16),
            ],
            
            // Summary and actions
            _buildBottomActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButtons(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _pickFiles,
          icon: const Icon(Icons.file_present),
          label: const Text('Pick Files'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _pickFolder,
          icon: const Icon(Icons.folder),
          label: const Text('Pick Folder'),
        ),
        if (_selectedFiles.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All'),
          ),
      ],
    );
  }

  Widget _buildFilesList(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading files...'),
          ],
        ),
      );
    }

    if (_selectedFiles.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.dividerColor,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_copy_outlined,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No files selected',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Use the buttons above to select files or folders',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
          return AnimatedFileCard(
            delay: Duration(milliseconds: index * 50),
            child: _buildFileItem(file, theme),
          );
        },
      ),
    );
  }

  Widget _buildFileItem(BatchFile file, ThemeData theme) {
    return ListTile(
      leading: _getFileIcon(file.name),
      title: Text(
        file.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(file.formattedSize),
      trailing: IconButton(
        onPressed: () => _removeFile(file),
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        tooltip: 'Remove file',
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description, color: Colors.blue);
      case 'xls':
      case 'xlsx':
        return const Icon(Icons.table_chart, color: Colors.green);
      case 'ppt':
      case 'pptx':
        return const Icon(Icons.slideshow, color: Colors.orange);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return const Icon(Icons.image, color: Colors.purple);
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return const Icon(Icons.video_file, color: Colors.indigo);
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return const Icon(Icons.audio_file, color: Colors.teal);
      case 'zip':
      case 'rar':
      case '7z':
        return const Icon(Icons.archive, color: Colors.brown);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Widget _buildCompressionSettings(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compress,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Compression Settings',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: _useCompression,
                onChanged: (value) {
                  setState(() {
                    _useCompression = value;
                  });
                },
              ),
            ],
          ),
          
          if (_useCompression && _compressionAnalysis != null) ...[
            const SizedBox(height: 12),
            Text(
              'Analysis: ${_compressionAnalysis!.compressibleFiles} compressible files (${_compressionAnalysis!.formattedCompressibleSize})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            
            // Compression level selector
            Row(
              children: [
                Text(
                  'Level:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<CompressionLevel>(
                    value: _compressionLevel,
                    isExpanded: true,
                    onChanged: (level) {
                      if (level != null) {
                        setState(() {
                          _compressionLevel = level;
                        });
                      }
                    },
                    items: CompressionLevel.values.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(level.displayName),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _smartCompression,
                      onChanged: (value) {
                        setState(() {
                          _smartCompression = value ?? true;
                        });
                      },
                    ),
                    Text(
                      'Smart',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            
            if (_compressionAnalysis!.alreadyCompressedFiles > 0)
              Text(
                '${_compressionAnalysis!.alreadyCompressedFiles} files already compressed (${_compressionAnalysis!.formattedAlreadyCompressedSize})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                ),
              ),
          ] else if (_useCompression) ...[
            const SizedBox(height: 8),
            Text(
              'Analyzing files for compression potential...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPeerSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.devices,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Device',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPeer?.name ?? 'No device selected',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // This would open peer selection dialog
              // For now, we'll use the default peer
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    final totalSize = _selectedFiles.fold<int>(
      0, 
      (sum, file) => sum + file.size,
    );
    
    return Row(
      children: [
        // Summary
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedFiles.length} files selected',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total size: ${_formatBytes(totalSize)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        
        // Actions
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectedFiles.isEmpty ? null : _confirmSelection,
          child: const Text('Send Files'),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final filePaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
            
        final batchFiles = await _batchService.createBatchFilesFromPaths(filePaths);
        
        setState(() {
          _selectedFiles.addAll(batchFiles);
        });
        
        // Analyze files for compression potential
        await _analyzeFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting files: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        final batchFiles = await _batchService.createBatchFilesFromPaths([selectedDirectory]);
        
        setState(() {
          _selectedFiles.addAll(batchFiles);
        });
        
        // Analyze files for compression potential
        await _analyzeFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting folder: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeFile(BatchFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _compressionAnalysis = null;
    });
  }
  
  /// Analyze selected files for compression potential
  Future<void> _analyzeFiles() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _compressionAnalysis = null;
      });
      return;
    }
    
    final filePaths = _selectedFiles.map((f) => f.path).toList();
    final analysis = await _compressionService.analyzeFiles(filePaths);
    
    setState(() {
      _compressionAnalysis = analysis;
      // Auto-recommend compression level
      _compressionLevel = _compressionService.getRecommendedLevel(filePaths);
    });
  }

  void _confirmSelection() {
    if (_selectedFiles.isNotEmpty) {
      widget.onFilesSelected(
        _selectedFiles, 
        _selectedPeer,
        useCompression: _useCompression,
        compressionLevel: _compressionLevel,
        smartCompression: _smartCompression,
      );
      Navigator.of(context).pop();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Helper function to show the multi-file picker dialog
Future<void> showMultiFilePicker(
  BuildContext context, {
  required Function(
    List<BatchFile> files, 
    Peer? targetPeer, {
    bool useCompression,
    CompressionLevel compressionLevel,
    bool smartCompression,
  }) onFilesSelected,
  Peer? defaultPeer,
  bool showPeerSelection = true,
}) {
  return showDialog(
    context: context,
    builder: (context) => MultiFilePicker(
      onFilesSelected: onFilesSelected,
      defaultPeer: defaultPeer,
      showPeerSelection: showPeerSelection,
    ),
  );
}
