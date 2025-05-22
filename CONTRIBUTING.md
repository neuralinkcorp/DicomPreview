# Contributing to DICOM QuickLook Preview

Thank you for your interest in contributing to DICOM QuickLook Preview! This document outlines the process for setting up your development environment and contributing to the project.

## Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 16.0 or later
- Rust toolchain (install via [rustup](https://rustup.rs/))
- Git

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub by clicking the "Fork" button

2. **Clone your fork** to your local machine:
   ```bash
   git clone https://github.com/YOUR_USERNAME/DicomPreview.git
   cd DicomPreview
   ```

3. **Set up the upstream remote** to keep your fork synchronized:
   ```bash
   git remote add upstream https://github.com/neuralinkcorp/DicomPreview.git
   git remote -v  # Verify remotes are set correctly
   ```

4. **Install Rust** if you haven't already:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

5. **Install pre-commit hooks** (optional but recommended):
   ```bash
   # Install pre-commit (if not already installed)
   pip install pre-commit
   # or with homebrew: brew install pre-commit
   
   # Install the hooks
   pre-commit install
   ```

6. **Build the project** to ensure everything works:
   ```bash
   # Build the Rust library
   ./build_rust_library.sh
   
   # Build the Xcode project
   xcodebuild -project DicomPreview.xcodeproj -scheme DicomPreview -configuration Release
   ```

## Pre-commit Hooks

This project uses pre-commit hooks to maintain code quality. The hooks are configured to run:

### Swift Code Quality
- **SwiftLint**: Enforces Swift style and conventions with strict mode enabled

### Rust Code Quality
- **cargo fmt**: Ensures consistent Rust code formatting
- **cargo clippy**: Rust linting with warnings treated as errors
- **cargo test**: Runs all Rust tests to ensure functionality

### Running Pre-commit Manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run only on staged files (normal pre-commit behavior)
pre-commit run
```

## Contributing Workflow

### Keeping Your Fork Updated

Before starting new work, sync your fork with the upstream repository:

```bash
# Fetch latest changes from upstream
git fetch upstream

# Switch to main branch
git checkout main

# Merge upstream changes
git merge upstream/main

# Push updates to your fork
git push origin main
```

### Making Changes

1. **Create a feature branch** from the latest main:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/AmazingFeature
   ```

2. **Make your changes** following the project conventions:
   - Swift code should follow SwiftLint guidelines
   - Rust code should be formatted with `cargo fmt`
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   # Test Rust components
   cd dicom-parser
   cargo test
   cargo clippy
   cargo fmt --check
   
   # Build and test the full application
   ./build_rust_library.sh
   xcodebuild -project DicomPreview.xcodeproj -scheme DicomPreview -configuration Debug -destination 'platform=macOS'
   ```

4. **Commit your changes** with descriptive messages:
   ```bash
   git add .
   git commit -m 'Add some AmazingFeature'
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/AmazingFeature
   ```

6. **Open a Pull Request** on GitHub with:
   - Clear description of the changes
   - Reference any related issues
   - Screenshots if UI changes are involved

## Reporting Issues

When reporting bugs or requesting features:
1. Search existing issues first
2. Use the issue templates when available
3. Include:
   - macOS version
   - DICOM file details (if applicable)
   - Steps to reproduce
   - Expected vs actual behavior

## Questions or Help

If you need help or have questions:
1. Check existing [Issues](https://github.com/neuralinkcorp/DicomPreview/issues) and [Discussions](https://github.com/neuralinkcorp/DicomPreview/discussions)
2. Open a new discussion for general questions
3. Open an issue for bugs or specific feature requests

Thank you for contributing to DICOM QuickLook Preview! 🎉 
