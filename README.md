# Stork - P2P File Transfer Application

Stork is a secure peer-to-peer file transfer application built with Tauri, providing a native desktop experience with web technologies. The application allows users to send and receive files directly between devices using a simple, intuitive interface.

## Features

- **Peer-to-Peer File Transfer**: Direct file transfers between devices without intermediary servers
- **Native File Dialog**: System-native file selection using Tauri's dialog plugin
- **Cross-Platform**: Built with Tauri for Windows, macOS, and Linux support
- **Modern UI**: Clean, responsive interface built with vanilla JavaScript, HTML, and CSS
- **Secure**: Local processing with no data sent to external servers

## Technology Stack

- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Backend**: Rust with Tauri framework
- **Build System**: Vite for frontend bundling
- **Package Manager**: pnpm

## Prerequisites

Before running this application, ensure you have the following installed:

- **Node.js** (v16 or later)
- **pnpm** package manager
- **Rust** (latest stable version)
- **Tauri CLI** (will be installed via pnpm)

### Installing Prerequisites

1. **Install Node.js**: Download from [nodejs.org](https://nodejs.org/)
2. **Install pnpm**: `npm install -g pnpm`
3. **Install Rust**: Follow instructions at [rustup.rs](https://rustup.rs/)
4. **Verify installations**:
   ```bash
   node --version
   pnpm --version
   rustc --version
   ```

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/cookiemp/stork.git
   cd stork
   ```

2. **Install dependencies**:
   ```bash
   pnpm install
   ```

3. **Install Tauri CLI** (if not already installed):
   ```bash
   pnpm add -D @tauri-apps/cli
   ```

## Development

### Running in Development Mode

To start the development server with hot reload:

```bash
pnpm run tauri:dev
```

This command will:
- Start the Vite development server for the frontend
- Compile the Rust backend
- Launch the Tauri application window
- Enable hot reload for both frontend and backend changes

### Available Scripts

- `pnpm run tauri:dev` - Start development server
- `pnpm run tauri:build` - Build production application
- `pnpm run dev` - Start frontend development server only
- `pnpm run build` - Build frontend for production
- `pnpm run preview` - Preview production build

## Building for Production

To create a production build:

```bash
pnpm run tauri:build
```

This will create platform-specific installers in the `src-tauri/target/release/bundle/` directory.

## Project Structure

```
stork/
├── public/                 # Static assets
├── src/                    # Frontend source code
│   ├── index.html         # Main HTML file
│   ├── script.js          # Application logic
│   └── style.css          # Styles
├── src-tauri/             # Tauri/Rust backend
│   ├── src/               # Rust source code
│   ├── tauri.conf.json    # Tauri configuration
│   ├── Cargo.toml         # Rust dependencies
│   └── build.rs           # Build script
├── package.json           # Node.js dependencies and scripts
├── vite.config.js         # Vite configuration
└── README.md              # This file
```

## Usage

### Sending Files

1. Launch the Stork application
2. Click the "Send" button on the main screen
3. Click "Select File" to open the native file dialog
4. Choose the file you want to transfer
5. The application will initiate the file transfer process

### Receiving Files

1. Launch the Stork application
2. Click the "Receive" button on the main screen
3. The application will listen for incoming file transfers
4. Accept incoming transfer requests when prompted

## Configuration

The application configuration is managed through:

- `src-tauri/tauri.conf.json` - Tauri-specific settings
- `vite.config.js` - Frontend build configuration
- `package.json` - Dependencies and scripts

## Troubleshooting

### Common Issues

1. **File dialog not opening**: Ensure the Tauri dialog plugin is properly configured
2. **Build failures**: Verify all prerequisites are installed and up to date
3. **Runtime errors**: Check the browser console (F12) for JavaScript errors
4. **Rust compilation errors**: Ensure Rust toolchain is properly installed

### Debug Mode

To enable debug logging, run the development server and check:
- Browser console (F12) for frontend logs
- Terminal output for Rust backend logs

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add feature description'`
5. Push to the branch: `git push origin feature-name`
6. Submit a pull request

### Development Guidelines

- Follow existing code style and conventions
- Write clear, descriptive commit messages
- Test changes on multiple platforms when possible
- Update documentation as needed

## Recommended IDE Setup

- **VS Code** with extensions:
  - [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode)
  - [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)
  - [ES6 String HTML](https://marketplace.visualstudio.com/items?itemName=Tobermory.es6-string-html)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing issues in the repository
3. Create a new issue with detailed information about the problem

## Acknowledgments

- Built with [Tauri](https://tauri.app/) - Build smaller, faster, and more secure desktop applications
- Powered by [Rust](https://www.rust-lang.org/) for the backend
- Frontend built with modern web technologies
