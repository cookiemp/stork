# 🚀 Stork P2P File Transfer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Windows%20|%20Android%20|%20macOS%20|%20Linux%20|%20Web-blue)](https://flutter.dev)
[![Security](https://img.shields.io/badge/Security-AES256%20|%20RSA2048-red)](https://github.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-blue)](https://flutter.dev)
[![Status](https://img.shields.io/badge/Status-Production%20Ready%20(Windows)-brightgreen)](https://github.com/)

**A secure, fast, and user-friendly peer-to-peer file transfer application built with Flutter**

Transform how you share files between devices on your local network with Stork P2P - the secure, lightning-fast file transfer solution that puts your privacy first.

---

## ✨ **Key Features**

### 🔐 **Enterprise-Grade Security**
- **End-to-End Encryption**: AES-256-GCM with RSA-2048 key exchange
- **PIN Protection**: Device-level authentication and authorization  
- **Perfect Forward Secrecy**: Session-specific encryption keys
- **Trusted Peer Management**: Secure peer approval and trust system
- **Transfer Approval**: Manual authorization for enhanced security

### 🌟 **Modern User Experience**
- **Material 3 Design**: Beautiful, responsive UI with dark/light themes
- **Drag & Drop Support**: Intuitive multi-file selection and sending
- **Real-Time Progress**: Live transfer progress with visual feedback
- **System Integration**: Native notifications and taskbar progress
- **Transfer History**: Complete audit trail of all file transfers
- **Onboarding Flow**: Guided first-time user experience

### ⚡ **High Performance**
- **Large File Support**: Efficient chunked transfers with resume capability
- **Multi-File Batches**: Concurrent transfer management (up to 3 simultaneous)
- **Smart Compression**: Automatic ZIP compression with optimization
- **Memory Efficient**: <100MB usage even for large file transfers
- **Network Adaptive**: Automatic peer discovery with manual fallback

---

## 🎯 **Quick Start**

### **Prerequisites**
- Windows 10/11 (for Windows build)
- Flutter 3.32.8 or later
- Visual Studio Build Tools 2019 or later

### **Installation**

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/stork-p2p.git
   cd stork-p2p
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Application**
   ```bash
   flutter run -d windows
   ```

### **First Launch**

1. **Onboarding**: Follow the guided setup for new users
2. **Security Setup**: Configure your PIN for device protection
3. **Network Discovery**: The app automatically discovers peers on your network
4. **Manual Peers**: Add peers manually using IP address if needed

---

## 📖 **How to Use**

### **Sending Files**

#### **Method 1: Direct Send**
- Enter target IP address in the input field
- Click "Send" for single files or "Multi" for multiple files

#### **Method 2: Peer Selection**  
- Add peers manually via "Add Peer" button
- Tap any peer in the list to send files directly

#### **Method 3: Drag & Drop**
- Drag files directly onto the app window
- Select target peer from the dialog
- Files are automatically transferred

### **Receiving Files**
- File receiving starts automatically
- Files are saved to your Downloads folder
- Get notified when files are received

---

## 🔧 **Configuration**

### **Security Settings**
- **PIN Protection**: Enable/disable device PIN lock
- **Transfer Approval**: Require manual approval for transfers  
- **Trusted Peers**: Manage your trusted device list
- **Anonymous Mode**: Allow transfers without authentication

### **Network Settings**
- **Default Port**: 8080 (configurable)
- **mDNS Discovery**: Automatic peer discovery on local network
- **Manual Peers**: Add peers by IP address and port

---

## 🏗️ **Architecture**

### **Project Structure**
```
stork/
├── lib/
│   ├── main.dart                          # App entry point with onboarding
│   ├── models/                            # Data models
│   │   ├── peer.dart                     # Peer data model
│   │   └── transfer_history.dart         # Transfer history model
│   ├── services/                          # Core services
│   │   ├── sender_service.dart           # File sending
│   │   ├── receiver_service.dart         # File receiving  
│   │   ├── security_manager.dart         # Security system
│   │   ├── encryption_service.dart       # Encryption/decryption
│   │   ├── batch_transfer_service.dart   # Multi-file transfers
│   │   ├── theme_service.dart            # Material 3 theming
│   │   └── notification_service.dart     # System notifications
│   ├── screens/                           # UI screens
│   │   ├── onboarding_screen.dart        # First-time user guide
│   │   ├── security_settings_screen.dart # Security configuration
│   │   └── transfer_history_screen.dart  # Transfer audit log
│   └── widgets/                           # Reusable UI components
├── test/                                  # Test files
├── windows/                               # Windows platform files
└── docs/                                  # Documentation
```

### **Key Technologies**
- **Flutter 3.32.8**: Cross-platform UI framework
- **Dart**: Programming language
- **Shelf**: HTTP server framework  
- **PointyCastle**: Cryptographic library
- **SharedPreferences**: Local data persistence
- **Desktop Drop**: Drag & drop file support

---

## 📊 **Performance**

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

## 🔒 **Security**

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

## 🧪 **Development**

### **Testing**

#### **Command Line Testing**
```bash
# Test receiver service
dart run test_receiver.dart

# Test complete flow
dart run test_core_services.dart

# Test security features  
dart run test_phase4_security.dart
```

#### **Integration Testing**
```bash
flutter test
```

### **Building**

#### **Windows Release**
```bash
flutter build windows --release
```

#### **Debug Build**
```bash
flutter run -d windows --debug
```

---

## 🛣️ **Roadmap**

### **Current Version (1.0.0) - ✅ Windows Ready**
- ✅ Windows desktop application
- ✅ End-to-end encryption
- ✅ Multi-file transfers  
- ✅ Modern UI with themes
- ✅ Transfer history
- ✅ Onboarding experience

### **Upcoming Features**
- 🔄 Android application
- 🔄 macOS application
- 🔄 Linux application
- 🔄 Web application (PWA)
- 🔄 Mobile-specific features (QR codes, NFC)
- 🔄 App store distributions

---

## 🤝 **Contributing**

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** your feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### **Development Setup**
1. Install Flutter 3.32.8+
2. Install Visual Studio Build Tools 2019+
3. Clone the repository
4. Run `flutter pub get`
5. Run `flutter analyze` to check code quality
6. Run tests with `flutter test`

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/yourusername/stork-p2p/issues)
- **Documentation**: [Full Documentation](docs/)
- **Security**: Report security issues via email

---

## 🎯 **Status**

**Stork P2P is production-ready for Windows** with comprehensive security, intuitive UX, and high-performance file transfers. The architecture is prepared for rapid cross-platform expansion.

### **Platform Support**
- **Windows**: ✅ **Production Ready**
- **Android**: 🔄 In Development
- **macOS**: 🔄 Planned  
- **Linux**: 🔄 Planned
- **Web**: 🔄 Planned

---

**Made with ❤️ using Flutter**

*Secure • Fast • Beautiful • Cross-Platform*