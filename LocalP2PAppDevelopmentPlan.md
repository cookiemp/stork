# Development Plan: Local P2P App (Flutter & Dart)

This document outlines the phased development plan for a local network peer-to-peer file sharing application using Flutter and Dart.

## Core Technologies

- **Framework**: Flutter
- **Language**: Dart
- **HTTP Server (Receiver)**: `shelf` & `shelf_router` packages
- **HTTP Client (Sender)**: `http` package
- **Device Discovery**: `multicast_dns` package
- **File Selection**: `file_picker` package

## Phase 1: The Core Transfer Logic

**Goal**: To transfer a file between two devices on the same network by manually typing in an IP address.

### Step 1.1: Design the API & Set Up Dependencies

- **Task**:
  1. In `pubspec.yaml`, add dependencies: `shelf`, `shelf_router`, `http`.
  2. Define API endpoints: `GET /info` and `POST /send` (with `X-Filename` header).
- **Test**: Run `flutter pub get` successfully.

### Step 1.2: Implement the “Receiver” (Shelf Server)

- **Task**: Create a service class to manage a `shelf` server. Use `shelf_router` to handle `/info` and `/send` routes. The `/send` handler must save the request body stream to a file.
- **Test**: Use `curl` from another machine to hit the `/info` and `/send` endpoints on the device running the app. The file must be saved correctly.

### Step 1.3: Implement the “Sender” (HTTP Client)

- **Task**: Create a service function that uses the `http` package to send a `StreamedRequest` containing the file data to the target IP address.
- **Test**: Trigger the `sendFile` function. The file must be successfully received by the other device.

## Phase 2: UI Shell & Wiring

**Goal**: To build the Flutter UI and connect it to the core networking services.

### Step 2.1: Build the Static UI with Flutter Widgets

- **Task**: Create a `StatefulWidget` with the main layout: buttons, a `TextField` for the IP, a `Switch` for discoverability, and an empty `ListView`.
- **Test**: The UI renders correctly without crashing.

### Step 2.2: Wire up the Sender UI

- **Task**: Use the `file_picker` package to select a file. Connect the “Send” button to the `sendFile` function, using the file and the IP from the `TextField`.
- **Test**: Send a file from one device to another using only the UI controls (but still typing the IP).

### Step 2.3: Wire up the Receiver UI

- **Task**: Connect the `Switch` to the `startServer()`/`stopServer()` methods. Use a callback from the server to update a `List<String>` in the UI’s state when a file is received, which rebuilds the `ListView`.
- **Test**: When a file is received, its name must automatically appear in the `ListView`.

## Phase 3: Automatic Local Discovery with mDNS

**Goal**: To eliminate manual IP address entry using `multicast_dns`.

### Step 3.1: Implement Service Broadcasting

- **Task**: When receiving is enabled, use `multicast_dns` to broadcast a `_localsendapp._tcp` service, advertising the device name and server port.
- **Test**: Use a command-line mDNS browser (like `dns-sd` or `avahi-browse`) to verify the service is visible on the network.

### Step 3.2: Implement Service Discovery

- **Task**: Use a `MulticastDnsClient` to listen for the `_localsendapp._tcp` service. Maintain a list of discovered peers (name, IP, port) in the UI’s state.
- **Test**: As devices running the app enable receiving on the network, they must appear in a debug console log on other devices.

## Phase 4: Full Integration and Polish

**Goal**: To create a seamless, user-friendly experience.

### Step 4.1: Create the Dynamic Peer List

- **Task**: Replace the IP `TextField` with a `ListView.builder` that displays the list of discovered peers from state.
- **Test**: Devices running the app must automatically appear in each other’s UI.

### Step 4.2: Finalize the “Send” Workflow

- **Task**: The `onTap` callback for a peer in the list should trigger the `sendFile` function using the stored IP and port.
- **Test**: The file transfer must work flawlessly by selecting a file and tapping a peer’s name.

### Step 4.3: Add Progress Indicators and Error Handling

- **Task**: Implement progress bars for sending/receiving by wrapping file streams or using package features. Use `try...catch` blocks for network calls and show user-friendly errors via `SnackBar` or `AlertDialog` widgets.
- **Test**: A progress bar must be visible during a large file transfer. The app must not crash and should show an error message if the network is interrupted.

---

## Phase 5: Security, Robustness & Quality Assurance

**Goal**: Harden the application for real-world usage, ensure consistent quality, and prepare for store release.

### Step 5.1: Security & Privacy

- **Task**:
  1. Add optional TLS support (self-signed certs for dev, user-accepted certs for production).
  2. Show an accept/deny dialog on the receiver before writing any file to disk.
  3. After each transfer, compute and verify a SHA-256 checksum.
- **Test**: Attempt a transfer with TLS enabled and confirm the checksum matches. Ensure the user must tap *Accept* before the file saves.

### Step 5.2: Transfer Robustness

- **Task**:
  1. Implement chunked uploads with automatic resume on failure.
  2. Stream files using back-pressure to avoid memory spikes on large transfers.
- **Test**: Force a network drop mid-transfer and confirm the sender resumes automatically without data corruption.

### Step 5.3: Cross-Platform Paths

- **Task**: Abstract the destination directory so each platform saves to an OS-appropriate *Downloads/LocalSend* folder.
- **Test**: Verify the saved location on Android, iOS, macOS, Windows, and Linux builds.

### Step 5.4: Discovery Enhancements

- **Task**:
  1. Include file-type/MIME hints in the mDNS TXT record for richer peer list UI.
  2. Add a fallback QR code that encodes `ip:port` for situations where mDNS is unavailable.
- **Test**: Confirm another device can discover via both mDNS and the QR code workflow.

### Step 5.5: Performance Metrics & Logging

- **Task**: Log transfer speed, retries, and failure reasons to a local file. Offer opt-in anonymous telemetry for aggregate performance metrics.
- **Test**: Review the log file and ensure metrics are recorded. Telemetry is only sent when the user opts in.

### Step 5.6: Continuous Integration & Testing

- **Task**:
  1. Add unit tests for sender/receiver services.
  2. Create an integration test that spins up two Flutter driver instances for an end-to-end transfer.
  3. Configure GitHub Actions (or similar) to run `flutter test`, build Android APK, and build iOS IPA (macOS runner).
- **Test**: CI passes on every push and fails if any test or build step breaks.

### Step 5.7: Code Quality Enforcement

- **Task**: Add pre-commit hooks to run `dart analyze` and `flutter format --set-exit-if-changed`.
- **Test**: A commit with formatting or analyzer issues is rejected.

### Step 5.8: UX Polish & Accessibility

- **Task**: Provide dark-mode friendly colors, human-readable file sizes, estimated remaining time, vibration/system notifications, and accessibility labels.
- **Test**: Manually verify UI in both light and dark themes and run *flutter accessibility* checks.

### Step 5.9: Release Checklist

- **Task**: Prepare store-ready assets: app icon, splash screen, localized strings, license screen, and file-type share intents.
- **Test**: Build release APK/IPA, install on devices, and verify share-into workflow works from other apps.
