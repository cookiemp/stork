import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:crypto/crypto.dart';
import '../utils/file_helper.dart';
import 'transfer_history_service.dart';
import '../models/transfer_history.dart';
import 'security_manager.dart';

/// Enum for pending transfer approval status
enum PendingTransferStatus {
  pending,
  approved,
  rejected,
}

/// Data model for a pending file transfer that requires approval
class PendingTransfer {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String senderInfo;
  final DateTime timestamp;
  final PendingTransferStatus status;

  const PendingTransfer({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.senderInfo,
    required this.timestamp,
    this.status = PendingTransferStatus.pending,
  });

  PendingTransfer copyWith({
    String? transferId,
    String? fileName,
    int? fileSize,
    String? senderInfo,
    DateTime? timestamp,
    PendingTransferStatus? status,
  }) {
    return PendingTransfer(
      transferId: transferId ?? this.transferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      senderInfo: senderInfo ?? this.senderInfo,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'PendingTransfer(id: $transferId, file: $fileName, size: $fileSize, sender: $senderInfo, status: $status)';
  }
}

class ReceiverService {
  HttpServer? _server;
  int _port = 8080;
  Function(String filename)? onFileReceived;
  TransferHistoryService? _historyService;
  SecurityManager? _securityManager;
  
  // Large file transfer state
  final Map<String, LargeFileTransfer> _activeTransfers = {};
  
  // Pending approval state
  final Map<String, PendingTransfer> _pendingTransfers = {};
  
  int get port => _port;
  bool get isRunning => _server != null;
  
  /// Set the transfer history service for logging received files
  void setHistoryService(TransferHistoryService historyService) {
    _historyService = historyService;
  }
  
  /// Set the security manager for approval workflows
  void setSecurityManager(SecurityManager securityManager) {
    _securityManager = securityManager;
  }
  
  /// Check if a transfer requires approval
  Future<bool> _requiresApproval(String senderIp, String fileName, int fileSize) async {
    if (_securityManager == null || !_securityManager!.isInitialized) {
      return false; // No security = no approval needed
    }
    
    // Get current security configuration
    final config = await _securityManager!.getSecurityConfigurationAsync();
    
    // If require approval is disabled, no approval needed
    if (!config.requireApproval) {
      return false;
    }
    
    // If auto-approve trusted peers is enabled, check if peer is trusted
    if (config.autoApproveTrustedPeers) {
      final peerId = '$senderIp:8080'; // Assume default port for peer ID
      return !await _securityManager!.shouldAutoApprove(peerId);
    }
    
    // Require approval for all transfers
    return true;
  }
  
  /// Request approval for a file transfer
  Future<String?> _requestApproval(String senderIp, String fileName, int fileSize) async {
    if (_securityManager == null) return null;
    
    final peerId = '$senderIp:8080';
    final peerName = senderIp; // Use IP as name for now
    
    try {
      final approvalId = await _securityManager!.requestTransferApproval(
        peerId: peerId,
        peerName: peerName,
        fileName: fileName,
        fileSize: fileSize,
        direction: SecurityTransferDirection.received,
      );
      
      return approvalId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to request transfer approval: $e');
      }
      return null;
    }
  }

  Future<void> startServer({int port = 8080}) async {
    if (_server != null) {
      print('Server already running on port $_port');
      return;
    }

    _port = port;
    final router = Router();

    // GET /info - Returns device info
    router.get('/info', (Request request) {
      final deviceInfo = {
        'device_name': Platform.localHostname,
        'port': _port,
        'version': '1.0.0',
      };
      
      return Response.ok(
        jsonEncode(deviceInfo),
        headers: {'Content-Type': 'application/json'},
      );
    });
    
    // POST /init_large_transfer - Initialize large file transfer
    router.post('/init_large_transfer', (Request request) async {
      return await _handleInitLargeTransfer(request);
    });
    
    // GET /check_resume/<transferId> - Check resume capability
    router.get('/check_resume/<transferId>', (Request request) async {
      return await _handleCheckResume(request);
    });
    
    // POST /send_chunk - Receive file chunk
    router.post('/send_chunk', (Request request) async {
      return await _handleSendChunk(request);
    });
    
    // POST /finalize_transfer - Finalize transfer and verify
    router.post('/finalize_transfer', (Request request) async {
      return await _handleFinalizeTransfer(request);
    });

    // POST /send - Receives file data
    router.post('/send', (Request request) async {
      try {
        // Get filename from header
        final filename = request.headers['x-filename'];
        if (filename == null || filename.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'error': 'Missing X-Filename header'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Basic security check
        if (!FileHelper.isSafeFile(filename)) {
          return Response.badRequest(
            body: jsonEncode({'error': 'File type not allowed'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        print('Receiving file: $filename');

        // Get platform-appropriate downloads directory
        final downloadsDir = await FileHelper.getDownloadsDirectory();
        
        // Generate safe filename to avoid conflicts
        final safeFileName = await FileHelper.getSafeFileName(filename, downloadsDir);
        
        // Save the file
        final filePath = '${downloadsDir.path}${Platform.pathSeparator}$safeFileName';
        final file = File(filePath);
        final sink = file.openWrite();

        await for (final chunk in request.read()) {
          sink.add(chunk);
        }
        await sink.close();

        print('File saved to: $filePath');
        
        // Log to transfer history
        await _logReceivedFileToHistory(filename, filePath, file.lengthSync());
        
        // Notify callback
        onFileReceived?.call(filename);

        return Response.ok(
          jsonEncode({'status': 'success', 'filename': filename}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Error receiving file: $e');
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to save file: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, _port);
      print('Server running on http://${_server!.address.host}:${_server!.port}');
    } catch (e) {
      print('Failed to start server: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('Server stopped');
    }
  }

  void dispose() {
    stopServer();
  }
  
  // --- Large File Transfer Handlers ---

  Future<Response> _handleInitLargeTransfer(Request request) async {
    try {
      final requestBody = await request.readAsString();
      final data = json.decode(requestBody);

      final fileName = data['fileName'] as String;
      final fileSize = data['fileSize'] as int;
      final fileHash = data['fileHash'] as String;
      final chunkSize = data['chunkSize'] as int;
      
      if (!FileHelper.isSafeFile(fileName)) {
        return Response.badRequest(body: 'File type not allowed');
      }

      final downloadsDir = await FileHelper.getDownloadsDirectory();
      final safeFileName = await FileHelper.getSafeFileName(fileName, downloadsDir);
      final filePath = '${downloadsDir.path}${Platform.pathSeparator}$safeFileName';
      final tempFilePath = '$filePath.part';
      
      final transferId = 'transfer_${DateTime.now().millisecondsSinceEpoch}';
      
      _activeTransfers[transferId] = LargeFileTransfer(
        id: transferId,
        fileName: safeFileName,
        filePath: filePath,
        tempFilePath: tempFilePath,
        totalSize: fileSize,
        expectedHash: fileHash,
        chunkSize: chunkSize,
        receivedChunks: {},
      );
      
      if (kDebugMode) {
        print('🚀 Initialized large file transfer: $transferId for $fileName');
      }
      
      return Response.ok(
        json.encode({'transferId': transferId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Initialization failed: $e');
    }
  }

  Future<Response> _handleCheckResume(Request request) async {
    final transferId = request.params['transferId']!;
    final transfer = _activeTransfers[transferId];

    if (transfer == null) {
      return Response.notFound('Transfer not found');
    }

    try {
      final tempFile = File(transfer.tempFilePath);
      int resumeOffset = 0;

      if (await tempFile.exists()) {
        final currentSize = await tempFile.length();
        
        // If file is complete size, validate hash before allowing resume
        if (currentSize == transfer.totalSize) {
          if (kDebugMode) {
            print('🔍 Resume check: File appears complete, validating hash...');
          }
          
          final existingHash = await _calculateFileHash(tempFile);
          if (existingHash == transfer.expectedHash) {
            if (kDebugMode) {
              print('✅ Resume check: File hash matches, can resume at end');
            }
            resumeOffset = currentSize;
          } else {
            if (kDebugMode) {
              print('❌ Resume check: File hash mismatch, deleting and starting fresh');
              print('   - Expected: ${transfer.expectedHash}');
              print('   - Found: $existingHash');
            }
            // Delete corrupted file and start fresh
            await tempFile.delete();
            resumeOffset = 0;
          }
        } else {
          // Partial file - for now, start fresh to avoid complexity
          // TODO: Implement proper partial resume with chunk validation
          if (kDebugMode) {
            print('⚠️ Resume check: Partial file found (${currentSize}/${transfer.totalSize}), restarting for safety');
          }
          await tempFile.delete();
          resumeOffset = 0;
        }
      }

      if (kDebugMode) {
        print('📊 Resume check result: offset = $resumeOffset');
      }

      return Response.ok(
        json.encode({'resumeOffset': resumeOffset}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Resume check error: $e');
      }
      return Response.internalServerError(body: 'Resume check failed: $e');
    }
  }

  Future<Response> _handleSendChunk(Request request) async {
    try {
      // Parse multipart form data
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        return Response.badRequest(body: 'Expected multipart/form-data');
      }

      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return Response.badRequest(body: 'No boundary found');
      }

      final bodyBytes = await _readRequestBytes(request);
      final parts = _parseMultipartData(bodyBytes, boundary);
      
      // Extract fields and chunk data
      String? transferId, chunkNumber, offset, chunkHash;
      List<int>? chunkData;
      
      for (final part in parts) {
        final name = _getFieldName(part.headers);
        if (name == null) continue;
        
        switch (name) {
          case 'transferId':
            transferId = utf8.decode(part.data);
            break;
          case 'chunkNumber':
            chunkNumber = utf8.decode(part.data);
            break;
          case 'offset':
            offset = utf8.decode(part.data);
            break;
          case 'chunkHash':
            chunkHash = utf8.decode(part.data);
            break;
          case 'chunk':
            chunkData = part.data;
            break;
        }
      }
      
      if (transferId == null || chunkNumber == null || offset == null || 
          chunkHash == null || chunkData == null) {
        return Response.badRequest(body: 'Missing required fields');
      }
      
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        return Response.notFound('Transfer not found');
      }

      // Verify chunk hash
      final receivedHash = sha256.convert(chunkData).toString();
      if (receivedHash != chunkHash) {
        if (kDebugMode) {
          print('⚠️ Chunk hash mismatch: expected $chunkHash, got $receivedHash');
        }
        return Response.badRequest(body: 'Chunk hash mismatch');
      }

      // Write chunk to temp file at specific offset
      final offsetInt = int.parse(offset);
      final chunkNum = int.parse(chunkNumber);
      
      final tempFile = File(transfer.tempFilePath);
      
      // Ensure temp file exists and is properly initialized
      if (!await tempFile.exists()) {
        // Create file and initialize it to the full expected size with zeros
        await tempFile.create();
        final initFile = await tempFile.open(mode: FileMode.writeOnly);
        try {
          // Set file size to expected total size
          await initFile.setPosition(transfer.totalSize - 1);
          await initFile.writeByte(0);
          await initFile.flush();
        } finally {
          await initFile.close();
        }
        if (kDebugMode) {
          print('📝 Initialized temp file with size: ${transfer.totalSize}');
        }
      }
      
      // Use writeOnlyAppend mode and then position to the specific offset
      final randomAccessFile = await tempFile.open(mode: FileMode.writeOnlyAppend);
      try {
        await randomAccessFile.setPosition(offsetInt);
        await randomAccessFile.writeFrom(chunkData);
        await randomAccessFile.flush();
      } finally {
        await randomAccessFile.close();
      }
      
      transfer.receivedChunks[chunkNum] = true;
      
      if (kDebugMode) {
        print('📦 Chunk $chunkNum received and written at offset $offsetInt (${chunkData.length} bytes)');
      }

      return Response.ok('Chunk received');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Chunk processing error: $e');
      }
      return Response.internalServerError(body: 'Chunk processing failed: $e');
    }
  }

  Future<Response> _handleFinalizeTransfer(Request request) async {
    try {
      final requestBody = await request.readAsString();
      final data = json.decode(requestBody);
      final transferId = data['transferId'] as String;

      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        return Response.notFound('Transfer not found');
      }

      // Verify file integrity
      final tempFile = File(transfer.tempFilePath);
      final tempFileExists = await tempFile.exists();
      final tempFileSize = tempFileExists ? await tempFile.length() : 0;
      
      if (kDebugMode) {
        print('🔍 Finalization debug:');
        print('   - Transfer ID: $transferId');
        print('   - Expected size: ${transfer.totalSize}');
        print('   - Actual size: $tempFileSize');
        print('   - File exists: $tempFileExists');
        print('   - Chunks received: ${transfer.receivedChunks.length}');
        print('   - Temp file path: ${transfer.tempFilePath}');
      }
      
      if (!tempFileExists || tempFileSize != transfer.totalSize) {
        if (kDebugMode) {
          print('❌ File size mismatch: expected ${transfer.totalSize}, got $tempFileSize');
        }
        return Response.badRequest(body: 'File size mismatch: expected ${transfer.totalSize}, got $tempFileSize');
      }

      // Final hash check
      if (kDebugMode) {
        print('🔐 Calculating final hash...');
      }
      
      final receivedHash = await _calculateFileHash(tempFile);
      
      if (kDebugMode) {
        print('🔐 Hash comparison:');
        print('   - Expected: ${transfer.expectedHash}');
        print('   - Received: $receivedHash');
        print('   - Match: ${receivedHash == transfer.expectedHash}');
      }
      
      if (receivedHash != transfer.expectedHash) {
        if (kDebugMode) {
          print('❌ Hash mismatch detected!');
        }
        return Response.badRequest(body: 'File hash mismatch: expected ${transfer.expectedHash}, got $receivedHash');
      }

      // Rename temp file to final file
      await tempFile.rename(transfer.filePath);
      
      // Log to transfer history
      await _logReceivedFileToHistory(transfer.fileName, transfer.filePath, transfer.totalSize);
      
      onFileReceived?.call(transfer.fileName);

      if (kDebugMode) {
        print('✅ Large file transfer finalized: ${transfer.fileName}');
      }

      _activeTransfers.remove(transferId);

      return Response.ok(json.encode({'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      if (kDebugMode) {
        print('❌ Finalization error: $e');
      }
      return Response.internalServerError(body: 'Finalization failed: $e');
    }
  }

  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // --- Multipart Parsing Helpers ---
  
  String? _extractBoundary(String contentType) {
    final boundaryMatch = RegExp(r'boundary=([^;]+)').firstMatch(contentType);
    return boundaryMatch?.group(1);
  }
  
  Future<List<int>> _readRequestBytes(Request request) async {
    final chunks = <List<int>>[];
    await for (final chunk in request.read()) {
      chunks.add(chunk);
    }
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = List<int>.filled(totalLength, 0);
    int offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
  
  List<_MultipartPart> _parseMultipartData(List<int> data, String boundary) {
    final parts = <_MultipartPart>[];
    final boundaryBytes = utf8.encode('--$boundary');
    final endBoundaryBytes = utf8.encode('--$boundary--');
    
    int start = 0;
    while (start < data.length) {
      // Find next boundary
      final boundaryIndex = _findBytes(data, boundaryBytes, start);
      if (boundaryIndex == -1) break;
      
      // Skip boundary
      start = boundaryIndex + boundaryBytes.length;
      
      // Skip CRLF after boundary
      if (start + 1 < data.length && data[start] == 13 && data[start + 1] == 10) {
        start += 2;
      }
      
      // Find end of headers (double CRLF)
      final headersEnd = _findBytes(data, [13, 10, 13, 10], start);
      if (headersEnd == -1) break;
      
      // Parse headers
      final headerBytes = data.sublist(start, headersEnd);
      final headerString = utf8.decode(headerBytes);
      final headers = _parseHeaders(headerString);
      
      // Find start of content
      final contentStart = headersEnd + 4;
      
      // Find next boundary to determine content end
      final nextBoundaryIndex = _findBytes(data, boundaryBytes, contentStart);
      int contentEnd;
      if (nextBoundaryIndex == -1) {
        // Check for end boundary
        final endBoundaryIndex = _findBytes(data, endBoundaryBytes, contentStart);
        contentEnd = endBoundaryIndex == -1 ? data.length : endBoundaryIndex;
      } else {
        contentEnd = nextBoundaryIndex;
      }
      
      // Remove trailing CRLF before boundary
      if (contentEnd >= 2 && data[contentEnd - 2] == 13 && data[contentEnd - 1] == 10) {
        contentEnd -= 2;
      }
      
      // Extract content
      final content = data.sublist(contentStart, contentEnd);
      parts.add(_MultipartPart(headers: headers, data: content));
      
      start = nextBoundaryIndex == -1 ? data.length : nextBoundaryIndex;
    }
    
    return parts;
  }
  
  int _findBytes(List<int> data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
  
  Map<String, String> _parseHeaders(String headerString) {
    final headers = <String, String>{};
    final lines = headerString.split('\r\n');
    for (final line in lines) {
      if (line.isEmpty) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim().toLowerCase();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }
    return headers;
  }
  
  String? _getFieldName(Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition == null) return null;
    
    final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
    return nameMatch?.group(1);
  }
  
  /// Log received file to transfer history
  Future<void> _logReceivedFileToHistory(String fileName, String filePath, int fileSize) async {
    final historyService = _historyService;
    if (historyService == null) {
      if (kDebugMode) {
        print('📝 Transfer history service not available, skipping history log');
      }
      return;
    }
    
    try {
      // Determine transfer type based on file size
      final transferType = fileSize > 10485760 ? TransferType.large : TransferType.single; // 10MB threshold
      
      // Create a completed transfer record for the received file
      final record = historyService.completeTransferRecord(
        record: historyService.createTransferRecord(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
          targetHost: 'Unknown', // We don't have sender IP in current implementation
          targetPort: _port,
          targetName: 'Unknown Device',
          direction: TransferDirection.received,
          type: transferType,
        ),
        finalStatus: TransferStatus.completed,
      );
      
      await historyService.addTransferRecord(record);
      
      if (kDebugMode) {
        print('📝 Logged received file to transfer history: ${record.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to log received file to transfer history: $e');
      }
    }
  }
}

// --- Data model for large file transfers ---

class LargeFileTransfer {
  final String id;
  final String fileName;
  final String filePath;
  final String tempFilePath;
  final int totalSize;
  final String expectedHash;
  final int chunkSize;
  final Map<int, bool> receivedChunks;

  LargeFileTransfer({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.tempFilePath,
    required this.totalSize,
    required this.expectedHash,
    required this.chunkSize,
    required this.receivedChunks,
  });
}

class _MultipartPart {
  final Map<String, String> headers;
  final List<int> data;
  
  _MultipartPart({required this.headers, required this.data});
}
