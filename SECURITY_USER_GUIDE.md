# Stork2 Security Features - User Guide

## How Security Will Work for You

The security features are **configurable** with secure defaults. Here's what you'll see and control:

---

## 🛡️ First Launch - Security Setup

### Initial Setup Screen
```
┌─────────────────────────────────────────┐
│  🔒 Secure Your File Transfers         │
├─────────────────────────────────────────┤
│                                         │
│  Set up security for Stork2:           │
│                                         │
│  📱 Device PIN: [    ] (Required)      │
│     └─ 4-6 digits for device access    │
│                                         │
│  [ Setup Later ]    [ Continue Setup ] │
└─────────────────────────────────────────┘
```

---

## ⚙️ Security Settings Menu

You'll have full control through a **Settings > Security** screen:

### Core Protection Settings
```
┌─────────────────────────────────────────┐
│  🔐 Authentication                      │
├─────────────────────────────────────────┤
│  PIN Protection          [●] ON         │
│  │ └─ Change PIN         [    Change  ] │
│  │ └─ Max attempts: 3    [ 3 ▼ ]      │
│  │ └─ Lockout time: Auto [ Auto ▼ ]    │
│                                         │
│  📋 Transfer Approval                   │
│  │ Require approval      [●] ON         │
│  │ Auto-approve trusted  [ ] OFF        │
│  │ Trust threshold: 70%  [████▒▒] 70%   │
└─────────────────────────────────────────┘
```

### Advanced Security Options
```
┌─────────────────────────────────────────┐
│  🔗 Session Management                  │
├─────────────────────────────────────────┤
│  Session timeout: 60 min [ 60 ▼ ]      │
│  Auto-cleanup expired   [●] ON          │
│                                         │
│  🚨 Threat Protection                   │
│  │ Block suspicious peers [●] ON        │
│  │ Security alerts       [●] ON         │
│  │ Emergency lockdown    [Activate]     │
└─────────────────────────────────────────┘
```

---

## 🎚️ Security Level Presets

You'll have **easy preset options**:

### Quick Setup Options
```
┌─────────────────────────────────────────┐
│  Choose Your Security Level:            │
├─────────────────────────────────────────┤
│                                         │
│  🟢 Basic Security                      │
│  │ • PIN protection                     │
│  │ • Manual approval for unknowns       │
│  │ • Basic threat detection             │
│  │                         [Select]     │
│                                         │
│  🟡 Balanced (Default)                  │
│  │ • PIN protection                     │
│  │ • Smart auto-approval                │
│  │ • Advanced threat detection          │
│  │                         [Select]     │
│                                         │
│  🔴 Maximum Security                    │
│  │ • PIN protection                     │
│  │ • Manual approval required           │
│  │ • Aggressive threat blocking         │
│  │                         [Select]     │
│                                         │
│  ⚙️  Custom Configuration               │
│  │ • Configure each setting             │
│  │                         [Select]     │
└─────────────────────────────────────────┘
```

---

## 📱 Day-to-Day User Experience

### When Someone Wants to Send You a File

**For Unknown Devices:**
```
┌─────────────────────────────────────────┐
│  📨 Incoming File Transfer              │
├─────────────────────────────────────────┤
│  From: John's iPhone                    │
│  File: vacation-photos.zip             │
│  Size: 2.4 MB                          │
│                                         │
│  ⚠️  This is a new device               │
│                                         │
│  [ Decline ]  [ Accept Once ]  [ Trust ] │
└─────────────────────────────────────────┘
```

**For Trusted Devices:**
```
┌─────────────────────────────────────────┐
│  📨 Auto-Approved Transfer              │
├─────────────────────────────────────────┤
│  ✅ From: Mom's iPad (Trusted)          │
│  📁 File: family-recipe.pdf             │
│  📊 Size: 156 KB                        │
│                                         │
│  🔒 Automatically approved              │
│  📥 Downloading...  ████▒▒▒ 60%         │
└─────────────────────────────────────────┘
```

### Trusted Device Management
```
┌─────────────────────────────────────────┐
│  👥 Trusted Devices                     │
├─────────────────────────────────────────┤
│  📱 John's iPhone        [Remove Trust] │
│  │  └─ Added: Yesterday                 │
│  │  └─ Transfers: 3 successful          │
│                                         │
│  💻 Mom's iPad          [Remove Trust] │
│  │  └─ Added: Last week                 │
│  │  └─ Transfers: 12 successful         │
│                                         │
│  🚫 Blocked Devices                     │
│  │  📱 Spam Device      [Unblock]       │
│  │  └─ Reason: Too many failed attempts │
│                                         │
│  [ + Add Trusted Device ]               │
└─────────────────────────────────────────┘
```

### Security Alerts
```
┌─────────────────────────────────────────┐
│  🚨 Security Alert                      │
├─────────────────────────────────────────┤
│  ⚠️  Suspicious Activity Detected       │
│                                         │
│  Device "Unknown-Android" attempted     │
│  5 failed transfers in 2 minutes       │
│                                         │
│  🔒 Device has been automatically       │
│      blocked for your protection        │
│                                         │
│  [ View Details ]          [ Dismiss ] │
└─────────────────────────────────────────┘
```

---

## 🎯 What's ON by Default vs Optional

### ✅ **ENABLED BY DEFAULT** (Secure by default)
- **PIN Protection** - You must set a PIN on first launch
- **Transfer Approval** - Unknown devices need approval
- **Encryption** - All transfers automatically encrypted
- **Session Timeouts** - Secure sessions expire after 1 hour
- **Basic Threat Detection** - Blocks obviously malicious behavior
- **Security Alerts** - Notifies you of security events

### ⚪ **OPTIONAL** (You can turn on/off)
- **Auto-approve Trusted Peers** - Default OFF (manual approval)
- **Aggressive Blocking** - Default OFF (basic blocking only)
- **Extended Session Times** - Default 60min (can extend)
- **Silent Mode** - Default OFF (shows all security alerts)

### 🔧 **CONFIGURABLE**
- **PIN Length** - 4-8 digits (default: 4)
- **Max Login Attempts** - 3-10 attempts (default: 3)
- **Trust Threshold** - 50%-90% (default: 70%)
- **Session Timeout** - 15min-8hrs (default: 60min)
- **Block Sensitivity** - Low/Medium/High (default: Medium)

---

## 🚀 Quick Start Recommendations

### For Most Users (Recommended)
```
✅ Use "Balanced" security preset
✅ Set a 4-digit PIN you'll remember
✅ Keep auto-approve OFF initially
✅ Add trusted devices as you use them
✅ Check security alerts when they appear
```

### For Casual Users
```
✅ Use "Basic" security preset
✅ Simple 4-digit PIN
✅ Turn ON auto-approve for convenience
✅ Ignore most security details
```

### For Security-Conscious Users
```
✅ Use "Maximum" security preset
✅ 6-8 digit PIN
✅ Keep auto-approve OFF
✅ Review all transfer requests
✅ Regularly check trusted device list
✅ Monitor security alerts actively
```

---

## 💡 Key Points

1. **Secure by Default** - The app starts with strong security enabled
2. **Progressive Trust** - Devices earn trust through successful transfers
3. **User Control** - You can adjust every security setting
4. **Transparency** - You'll see exactly what's happening and why
5. **Convenience Options** - Can trade some security for convenience if desired

The goal is to keep you safe while staying out of your way for legitimate file transfers!
