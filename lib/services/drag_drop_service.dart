import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

/// Service for handling drag and drop operations
class DragDropService {
  /// Check if the dropped files are valid for sending
  static bool areFilesValid(List<XFile> files) {
    if (files.isEmpty) return false;
    
    // For now, we'll support any file type
    // In the future, we could add size limits or type restrictions
    return true;
  }
  
  /// Get file information from XFile
  static Future<FileInfo> getFileInfo(XFile file) async {
    final fileStat = await File(file.path).stat();
    return FileInfo(
      name: file.name,
      path: file.path,
      size: fileStat.size,
      lastModified: fileStat.modified,
    );
  }
  
  /// Get multiple file information from XFiles
  static Future<List<FileInfo>> getMultipleFileInfo(List<XFile> files) async {
    final List<FileInfo> fileInfos = [];
    for (final file in files) {
      fileInfos.add(await getFileInfo(file));
    }
    return fileInfos;
  }
}

/// File information class
class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;
  
  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
  });
  
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  @override
  String toString() => 'FileInfo(name: $name, size: $formattedSize)';
}

/// Drag and drop overlay widget
class DragDropOverlay extends StatefulWidget {
  final Widget child;
  final Function(List<XFile>) onFilesDropped;
  final String? hintText;
  
  const DragDropOverlay({
    Key? key,
    required this.child,
    required this.onFilesDropped,
    this.hintText,
  }) : super(key: key);
  
  @override
  State<DragDropOverlay> createState() => _DragDropOverlayState();
}

class _DragDropOverlayState extends State<DragDropOverlay>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _startDragAnimation() {
    setState(() {
      _isDragging = true;
    });
    _animationController.forward();
  }
  
  void _endDragAnimation() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        DropTarget(
          onDragEntered: (details) {
            _startDragAnimation();
          },
          onDragExited: (details) {
            _endDragAnimation();
          },
          onDragDone: (details) {
            _endDragAnimation();
            if (DragDropService.areFilesValid(details.files)) {
              widget.onFilesDropped(details.files);
            }
          },
          child: widget.child,
        ),
        if (_isDragging)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(_opacityAnimation.value * 0.1),
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(_opacityAnimation.value),
                      width: 3.0,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(_opacityAnimation.value * 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 64,
                              color: theme.primaryColor.withOpacity(_opacityAnimation.value),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.hintText ?? 'Drop files here to send',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.primaryColor.withOpacity(_opacityAnimation.value),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Release to select files',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.primaryColor.withOpacity(_opacityAnimation.value * 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// File selection dialog widget for multiple file drops
class FileSelectionDialog extends StatefulWidget {
  final List<FileInfo> files;
  final Function(List<FileInfo>) onFilesConfirmed;
  final VoidCallback onCancel;
  
  const FileSelectionDialog({
    Key? key,
    required this.files,
    required this.onFilesConfirmed,
    required this.onCancel,
  }) : super(key: key);
  
  @override
  State<FileSelectionDialog> createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<FileSelectionDialog> {
  late Set<int> selectedIndices;
  
  @override
  void initState() {
    super.initState();
    // Start with all files selected
    selectedIndices = Set<int>.from(Iterable<int>.generate(widget.files.length));
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Select Files to Send (${widget.files.length} files)'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedIndices = Set<int>.from(Iterable<int>.generate(widget.files.length));
                    });
                  },
                  child: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedIndices.clear();
                    });
                  },
                  child: const Text('Select None'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  final isSelected = selectedIndices.contains(index);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedIndices.add(index);
                        } else {
                          selectedIndices.remove(index);
                        }
                      });
                    },
                    title: Text(
                      file.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${file.formattedSize} • ${file.lastModified.toString().split('.')[0]}',
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: Icon(
                      _getFileIcon(file.name),
                      color: isSelected ? theme.primaryColor : theme.iconTheme.color,
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Text(
              '${selectedIndices.length} of ${widget.files.length} files selected',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: selectedIndices.isEmpty ? null : () {
            final selectedFiles = selectedIndices.map((index) => widget.files[index]).toList();
            widget.onFilesConfirmed(selectedFiles);
          },
          icon: const Icon(Icons.send),
          label: Text('Send ${selectedIndices.length} Files'),
        ),
      ],
    );
  }
  
  /// Get file icon based on extension
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}
