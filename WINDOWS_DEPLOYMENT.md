# Windows Deployment Guide - Stork P2P

This guide provides step-by-step instructions for building, deploying, and distributing Stork P2P on Windows.

## 🎯 **Quick Start**

### **For End Users**

1. **Download** the installer from the releases page
2. **Run** `StorkP2P-Setup.exe` as administrator
3. **Launch** Stork P2P from the Start Menu
4. **Follow** the onboarding guide for first-time setup

### **For Developers**

1. **Prerequisites**: Flutter 3.32.8+, Visual Studio Build Tools 2019+
2. **Clone**: `git clone https://github.com/yourusername/stork-p2p.git`
3. **Install**: `flutter pub get`
4. **Run**: `flutter run -d windows`

---

## 🏗️ **Building from Source**

### **Prerequisites**

1. **Flutter SDK**: Version 3.32.8 or later
   ```bash
   flutter --version
   # Should show Flutter 3.32.8 or later
   ```

2. **Visual Studio Build Tools**: 2019 or later
   - Download from [Microsoft](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2019)
   - Install C++ build tools workload

3. **Windows 10/11**: Version 1903 or later

### **Development Build**

```bash
# Clone the repository
git clone https://github.com/yourusername/stork-p2p.git
cd stork-p2p

# Install dependencies
flutter pub get

# Verify installation
flutter doctor

# Run in debug mode
flutter run -d windows
```

### **Release Build**

```bash
# Clean previous builds
flutter clean

# Build release version
flutter build windows --release

# Output location
# build/windows/x64/runner/Release/stork.exe
```

### **Build Troubleshooting**

#### **Common Issues**

1. **CMake Errors**: Ensure Visual Studio Build Tools are properly installed
2. **File Lock Errors**: Disable antivirus temporarily or exclude project folder
3. **OneDrive Sync Issues**: Move project outside OneDrive folder for building

#### **File Lock Solutions**

```bash
# If build fails with file lock errors:
1. Close all IDEs (VS Code, IntelliJ)
2. Stop OneDrive sync temporarily
3. Exclude project folder from antivirus real-time protection
4. Run flutter clean && flutter build windows --release
```

---

## 📦 **Creating an Installer**

### **Using NSIS (Recommended)**

1. **Install NSIS**: Download from [nsis.sourceforge.io](https://nsis.sourceforge.io/)

2. **Create installer script** (`installer.nsi`):

```nsis
!define APPNAME "Stork P2P"
!define COMPANYNAME "Stork P2P"
!define DESCRIPTION "Secure P2P File Transfer"
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0

!define INSTALLSIZE 50000  # Size in KB

RequestExecutionLevel admin

InstallDir "$PROGRAMFILES64\${COMPANYNAME}\${APPNAME}"

Name "${APPNAME}"
Icon "assets\icon.ico"
outFile "StorkP2P-Setup.exe"

page directory
page instfiles

!macro VerifyUserIsAdmin
UserInfo::GetAccountType
pop $0
${If} $0 != "admin"
    messageBox mb_iconstop "Administrator rights required!"
    setErrorLevel 740 ;ERROR_ELEVATION_REQUIRED
    quit
${EndIf}
!macroend

function .onInit
	setShellVarContext all
	!insertmacro VerifyUserIsAdmin
functionEnd

section "install"
	setOutPath $INSTDIR
	file /r "build\windows\x64\runner\Release\*.*"
	
	writeUninstaller "$INSTDIR\uninstall.exe"
	
	createDirectory "$SMPROGRAMS\${COMPANYNAME}"
	createShortCut "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk" "$INSTDIR\stork.exe" "" "$INSTDIR\stork.exe"
	createShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\stork.exe" "" "$INSTDIR\stork.exe"
	
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayName" "${APPNAME}"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "InstallLocation" "$\"$INSTDIR$\""
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayIcon" "$\"$INSTDIR\stork.exe$\""
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "Publisher" "${COMPANYNAME}"
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMajor" ${VERSIONMAJOR}
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMinor" ${VERSIONMINOR}
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoModify" 1
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoRepair" 1
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "EstimatedSize" ${INSTALLSIZE}
sectionEnd

section "uninstall"
	delete "$INSTDIR\*.*"
	delete "$INSTDIR\data\*.*"
	rmDir "$INSTDIR\data"
	rmDir "$INSTDIR"
	
	delete "$SMPROGRAMS\${COMPANYNAME}\${APPNAME}.lnk"
	rmDir "$SMPROGRAMS\${COMPANYNAME}"
	delete "$DESKTOP\${APPNAME}.lnk"
	
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}"
sectionEnd
```

3. **Compile installer**:
   ```bash
   makensis installer.nsi
   ```

### **Using Advanced Installer (Alternative)**

1. **Download**: [Advanced Installer](https://www.advancedinstaller.com/)
2. **Import**: Add files from `build\windows\x64\runner\Release\`
3. **Configure**: Set app name, version, shortcuts
4. **Build**: Generate MSI installer

---

## 🚀 **Distribution Options**

### **Direct Download**

1. **GitHub Releases**: Upload installer to GitHub releases
2. **Website**: Host installer on your website
3. **File Sharing**: Use cloud storage services

### **Microsoft Store**

1. **Requirements**: 
   - Microsoft Developer Account ($19)
   - App certification process
   - MSIX package format

2. **Process**:
   ```bash
   # Convert to MSIX using Flutter
   flutter build windows --release
   # Use Visual Studio to package as MSIX
   ```

### **Chocolatey Package**

1. **Create package spec** (`stork-p2p.nuspec`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>stork-p2p</id>
    <version>1.0.0</version>
    <title>Stork P2P File Transfer</title>
    <authors>Your Name</authors>
    <description>Secure P2P file transfer application</description>
    <projectUrl>https://github.com/yourusername/stork-p2p</projectUrl>
    <tags>p2p file-transfer security</tags>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
```

2. **Submit** to Chocolatey community packages

---

## 🛡️ **Security Considerations**

### **Code Signing**

1. **Get Certificate**: Purchase code signing certificate
2. **Sign Executable**:
   ```bash
   signtool sign /f "certificate.pfx" /p "password" /t "http://timestamp.verisign.com/scripts/timstamp.dll" "stork.exe"
   ```

### **Antivirus Compatibility**

- **Test** with major antivirus software
- **Submit** false positive reports if detected
- **Consider** signing certificate for reputation

### **Windows Defender SmartScreen**

- **Code signing** helps with reputation
- **Build** download history gradually
- **Monitor** SmartScreen blocks and reports

---

## 📁 **File Structure**

### **Release Build Contents**
```
stork.exe                  # Main executable
flutter_windows.dll       # Flutter engine
data/
  flutter_assets/          # App assets
  icudtl.dat              # ICU data
app.so                    # AOT compiled Dart code (Release only)
```

### **Installation Directory**
```
C:\Program Files\Stork P2P\
├── stork.exe              # Main application
├── flutter_windows.dll   # Flutter runtime
├── data/                  # Application data
├── uninstall.exe          # Uninstaller (if using NSIS)
└── README.txt             # Basic usage information
```

---

## ⚡ **Performance Optimization**

### **Release Build Settings**

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/
    # Only include necessary assets
```

### **Build Flags**

```bash
# Optimize for size
flutter build windows --release --split-debug-info=symbols

# Tree shake icons
flutter build windows --release --tree-shake-icons
```

### **Runtime Optimizations**

- **Enable** hardware acceleration
- **Minimize** startup services
- **Lazy load** heavy components

---

## 🧪 **Testing**

### **Automated Testing**

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

### **Manual Testing Checklist**

- [ ] **Installation**: Installer runs without errors
- [ ] **First Launch**: Onboarding flow completes
- [ ] **Security Setup**: PIN configuration works
- [ ] **File Transfer**: Send/receive files successfully
- [ ] **Network Discovery**: Peers are discovered
- [ ] **Manual Peers**: Add peers by IP works
- [ ] **Drag & Drop**: File drag and drop functions
- [ ] **Notifications**: System notifications appear
- [ ] **History**: Transfer history is logged
- [ ] **Themes**: Light/dark theme switching
- [ ] **Uninstall**: Clean uninstallation

### **Performance Testing**

```bash
# Large file transfer test
# Memory usage monitoring
# Network speed benchmarking
# Concurrent transfer testing
```

---

## 🐛 **Troubleshooting**

### **Common Installation Issues**

1. **"App can't run on this PC"**: Install Visual C++ Redistributable
2. **Missing DLL errors**: Ensure all Flutter dependencies are included
3. **Firewall blocks**: Configure Windows Firewall exceptions
4. **Port conflicts**: Change default port in settings

### **Runtime Issues**

1. **Slow peer discovery**: Check network configuration
2. **Transfer failures**: Verify firewall and network settings  
3. **High memory usage**: Monitor for memory leaks in logs
4. **UI freezing**: Check for blocking operations on main thread

### **Debug Information**

```bash
# Enable verbose logging
flutter run -d windows --verbose

# Check Windows Event Viewer
# Application and System logs for errors
```

---

## 📊 **Deployment Metrics**

### **File Sizes**
- **Debug Build**: ~80-120 MB
- **Release Build**: ~40-60 MB
- **Installer**: ~50-70 MB

### **System Requirements**
- **OS**: Windows 10 version 1903+ or Windows 11
- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 200 MB available space
- **Network**: Local network access required

### **Performance Targets**
- **Startup Time**: < 3 seconds
- **Memory Usage**: < 100 MB during normal operation
- **Transfer Speed**: Network-limited (typically 5-50 MB/s)

---

## 🔄 **Updates**

### **Manual Update Process**

1. **Download** new installer
2. **Run installer** (will upgrade existing installation)
3. **Restart** application

### **Auto-Update (Future)**

```dart
// Planned auto-update implementation
class UpdateService {
  Future<void> checkForUpdates() async {
    // Check GitHub releases API
    // Download and apply updates
  }
}
```

---

## 📞 **Support**

### **User Support**

- **Documentation**: Comprehensive user guides
- **FAQ**: Common questions and solutions  
- **GitHub Issues**: Bug reports and feature requests
- **Community**: Discord/Reddit communities

### **Developer Support**

- **Build Issues**: Check Flutter doctor output
- **Debugging**: Use Flutter DevTools
- **Performance**: Profile with Flutter Inspector
- **Platform Issues**: Windows-specific debugging tools

---

**Deployment Guide Version**: 1.0  
**Last Updated**: January 2025  
**Compatible with**: Stork P2P v1.0.0+