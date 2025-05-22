#!/bin/bash

# Exit on any error
set -e

# Script configuration
RUST_MIN_VERSION="1.70.0"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_DIR="${PROJECT_ROOT}/dicom-parser"
KIT_DIR="${PROJECT_ROOT}/DicomPreviewExtension"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_rust_version() {
    if ! command -v rustc &> /dev/null; then
        log_error "Rust is not installed. Please install it from https://rustup.rs/"
        exit 1
    fi

    local rust_version=$(rustc --version | cut -d' ' -f2)
    
    # Compare versions using sort -V (version sort)
    # If the minimum version comes after the current version when sorted, 
    # then the current version is too old
    if [ "$(printf '%s\n%s\n' "${rust_version}" "${RUST_MIN_VERSION}" | sort -V | head -n1)" != "${RUST_MIN_VERSION}" ]; then
        log_error "Rust version ${rust_version} is too old. Please upgrade to ${RUST_MIN_VERSION} or later"
        exit 1
    fi
}

build_rust_library() {
    log_info "Building Rust library..."
    
    # Ensure Rust source directory exists
    if [ ! -d "${PARSER_DIR}" ]; then
        log_error "Rust source directory not found at ${PARSER_DIR}"
        exit 1
    fi
    
    cd "${PARSER_DIR}"
    
    # Set additional environment variables for consistent macOS deployment target
    export MACOSX_DEPLOYMENT_TARGET=14.0
    export CMAKE_OSX_DEPLOYMENT_TARGET=14.0
    export CFLAGS="${CFLAGS} -mmacosx-version-min=14.0"
    export CXXFLAGS="${CXXFLAGS} -mmacosx-version-min=14.0"
    
    # Build for ARM64
    log_info "Building for ARM64..."
    if ! cargo build --release --target aarch64-apple-darwin; then
        log_error "Failed to build Rust library for ARM64"
        exit 1
    fi

    # Build for x86_64
    log_info "Building for x86_64..."
    if ! cargo build --release --target x86_64-apple-darwin; then
        log_error "Failed to build Rust library for x86_64"
        exit 1
    fi

    # Ensure output directories exist
    mkdir -p "${KIT_DIR}/lib"
    
    # Create universal binary using lipo
    log_info "Creating universal binary..."
    lipo -create \
        "target/aarch64-apple-darwin/release/libdicom_parser.a" \
        "target/x86_64-apple-darwin/release/libdicom_parser.a" \
        -output "${KIT_DIR}/lib/libdicom_parser.a"
    
    log_info "Rust library built successfully!"
}

main() {
    log_info "Starting build process..."
    
    # Check requirements
    check_rust_version
    
    # Build the library
    build_rust_library
    
    log_info "Build completed successfully!"
    log_info "Integration instructions:"
    echo "
=================================================================
To integrate with Xcode:

1. In Xcode project settings:
   - Add '${KIT_DIR}/lib' to 'Library Search Paths'
   - Add '${KIT_DIR}/include' to 'Header Search Paths'
   - Add 'libdicom_parser.a' to 'Link Binary With Libraries'

2. Add this build script to Run Script phase:
   ${PROJECT_ROOT}/build_rust_library.sh
=================================================================
"
}

# Run the script
main
