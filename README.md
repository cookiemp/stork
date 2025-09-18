# Stork P2P File Transfer

**A secure, fast, and user-friendly peer-to-peer file transfer application built with Flutter**

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](https://github.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20|%20Android%20|%20macOS%20|%20Linux%20|%20Web-blue)](https://flutter.dev)
[![Security](https://img.shields.io/badge/Security-AES256%20|%20RSA2048-red)](https://github.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-blue)](https://flutter.dev)

---

## Features

### Enterprise-Grade Security
- End-to-End Encryption: AES-256-GCM with RSA-2048 key exchange
- PIN Protection: Device-level authentication and authorization
- Perfect Forward Secrecy: Session-specific encryption keys
- Trusted Peer Management: Secure peer approval and trust system
- Transfer Approval: Manual authorization for enhanced security

### Modern User Experience
- Material 3 Design: Responsive UI with dark/light themes
- Drag & Drop Support: Intuitive multi-file selection and sending
- Real-Time Progress: Live transfer progress with visual feedback
- System Integration: Native notifications and taskbar progress
- Transfer History: Complete audit trail of all file transfers

### High Performance
- Large File Support: Efficient chunked transfers with resume capability
- Multi-File Batches: Concurrent transfer management (up to 3 simultaneous)
- Smart Compression: Automatic ZIP compression with optimization
- Memory Efficient: <100MB usage even for large file transfers
- Network Adaptive: Automatic peer discovery with manual fallback

### Cross-Platform Ready
- Windows: Production ready
- Android: In development
- macOS: Planned
- Linux: Planned
- Web: Planned

---

## Quick Start

### **Prerequisites**
- Windows 10/11 (for Windows build)
- Flutter 3.32.8 or later
- Visual Studio Build Tools 2019 or later

### **Installation**

1. **Clone the Repository**
   ```bash
   git clone https://github.com/username/stork-p2p.git
   cd stork-p2p
   ```

2. **Install Dependencies**
   ```bash
   flutter\bin\flutter.bat pub get
   ```

3. **Run the Application**
   ```bash
   flutter\bin\flutter.bat run -d windows
   ```

### **First Launch Setup**

1. **Security Setup**: On first launch, you'll be prompted to set up a PIN for security
2. **Network Discovery**: The app automatically starts discovering peers on your network
3. **Manual Peers**: Add peers manually using IP address if auto-discovery doesn't work

---

## How to Use

### Sending Files

#### Method 1: Direct Send
1. Enter target IP address in the input field
2. Click "Send" button to select and send a single file
3. Click "Multi" button for multiple files or folders

#### Method 2: Peer Selection
1. Add peers manually via "Add Peer" button
2. Tap any peer in the list to send files directly
3. Use drag & drop to send files to specific peers

#### Method 3: Drag & Drop
1. Drag files directly onto the app window
2. Select target peer from the dialog
3. Files are automatically transferred

### Receiving Files

1. Auto-Start: File receiving starts automatically in debug mode
2. Manual Control: Use the "Start Receiving" toggle
3. Default Location: Files are saved to your Downloads folder
4. Notifications: Get notified when files are received

### Security Features

1. PIN Setup: Configure your security PIN on first launch
2. Trusted Peers: Approve peers for automatic file acceptance
3. Transfer Approval: Manually approve each file transfer
4. Encryption: All transfers are encrypted by default

---

## Configuration

### **Security Settings**
- **PIN Protection**: Enable/disable device PIN lock
- **Transfer Approval**: Require manual approval for transfers
- **Trusted Peers**: Manage your trusted device list
- **Anonymous Mode**: Allow transfers without authentication

### **Network Settings**
- **Default Port**: 8080 (configurable)
- **mDNS Discovery**: Automatic peer discovery on local network
- **Manual Peers**: Add peers by IP address and port

### **Transfer Settings**
- **Concurrent Transfers**: Up to 3 simultaneous transfers
- **Compression**: Automatic ZIP compression for multiple files
- **Chunk Size**: 1MB chunks for large file transfers
- **Resume Support**: Automatic transfer resume on interruption

---

## Development

### **Project Structure**
```
stork2/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── models/                            # Data models
│   ├── services/                          # Core services
│   │   ├── sender_service.dart           # File sending
│   │   ├── receiver_service.dart         # File receiving
│   │   ├── security_manager.dart         # Security system
│   │   ├── encryption_service.dart       # Encryption/decryption
│   │   └── batch_transfer_service.dart   # Multi-file transfers
│   ├── screens/                          # UI screens
│   └── widgets/                          # Reusable UI components
├── test/                                 # Test files
├── windows/                              # Windows platform files
└── docs/                                 # Documentation
```

### **Key Technologies**
- **Flutter 3.32.8**: Cross-platform UI framework
- **Dart**: Programming language
- **Shelf**: HTTP server framework
- **PointyCastle**: Cryptographic library
- **SharedPreferences**: Local data persistence
- **Desktop Drop**: Drag & drop file support

### **Testing**

#### Command Line Testing
```bash
# Test receiver service
dart run test_receiver.dart

# Test complete flow
dart run test_core_services.dart

# Test security features
dart run test_phase4_security.dart
```

#### Integration Testing
```bash
flutter test
```

---

## Performance

### **Benchmarks**
- **Small Files (<1MB)**: Instant transfer
- **Large Files (>10MB)**: 5.7 MB/s average (network dependent)
- **Memory Usage**: <100MB during large file transfers
- **Startup Time**: ~2 seconds (cold start)
- **Concurrent Transfers**: Up to 3 simultaneous without performance impact

### **Security Performance**
- **Encryption Overhead**: <5% impact on transfer speed
- **Key Generation**: ~2-5 seconds (one-time per device)
- **Session Setup**: <200ms per peer connection
- **Authentication**: <100ms PIN verification

---

## Security

### **Encryption Standards**
- **Symmetric**: AES-256-GCM with authenticated encryption
- **Asymmetric**: RSA-2048 for key exchange
- **Hashing**: SHA-256 for integrity verification
- **Random Generation**: Cryptographically secure PRNG (Fortuna)

### **Security Features**
- **Perfect Forward Secrecy**: Each session uses unique encryption keys
- **PIN Protection**: Device-level authentication with PBKDF2 hashing
- **Peer Trust Management**: Whitelist-based access control
- **Transfer Approval**: Manual authorization for enhanced security
- **Audit Logging**: Complete transfer history with security events

### **Privacy**
- **Anonymous Mode**: Optional anonymous transfers
- **Local Operation**: No cloud services or external dependencies
- **Data Retention**: Configurable transfer history retention
- **Secure Deletion**: Cryptographic key cleanup on session end

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Support

- **Documentation**: [Full Documentation](docs/)
- **Issues**: [GitHub Issues](https://github.com/username/stork-p2p/issues)
- **Security**: Report security issues via email

---

## Roadmap

### Current Version (1.0.0)
- Windows desktop application
- End-to-end encryption
- Multi-file transfers
- Modern UI with themes
- Transfer history

### Upcoming Features
- Android application
- macOS application
- Linux application
- Web application (PWA)
- Mobile-specific features (QR codes, NFC)
- App store distributions

---

**Made with Flutter**
