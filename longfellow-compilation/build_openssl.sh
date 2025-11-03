#!/bin/bash

#
# build_openssl.sh
#
# This is a universal script to build OpenSSL for iOS, Android, macOS, and Linux.
# It creates static libraries and, where appropriate, XCFrameworks.
#
# Usage:
#   ./build_openssl.sh <platform>
#
# Supported Platforms:
#   ios
#   android
#   macos
#   linux
#
# Prerequisites:
#   - For Android: Android NDK must be installed and 'ANDROID_NDK_ROOT' must be set.
#   - For iOS/macOS: Xcode Command Line Tools must be installed.
#   - For Linux: A C compiler (like gcc) and make are required.
#

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status

set -x

OPENSSL_VERSION="openssl-3.3.1"
ANDROID_API_LEVEL=21
MIN_IOS_SDK_VERSION="13.0"

# --- Script Setup ---
TARGET_PLATFORM=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/source/openssl"
OUTPUT_DIR="${SCRIPT_DIR}/output/openssl/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/openssl/${TARGET_PLATFORM}"

# --- Helper Functions ---
log() {
    echo ""
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
    echo ""
}

clone_openssl() {
    if [ ! -d "${SOURCE_DIR}" ]; then
        log "Cloning OpenSSL source code (version ${OPENSSL_VERSION})..."
        git clone --depth 1 --branch ${OPENSSL_VERSION} https://github.com/openssl/openssl.git "${SOURCE_DIR}"
    else
        log "OpenSSL source directory found. Checking out version ${OPENSSL_VERSION}..."
        cd "${SOURCE_DIR}"
        git fetch --all --tags
        git checkout ${OPENSSL_VERSION}
        cd ..
    fi
}

# --- Platform Build Functions ---

##
# iOS Build Function
##
build_ios() {
    log "Starting iOS build..."

    # Function to build a specific iOS architecture
    build_ios_arch() {
        local ARCH=$1
        local PLATFORM=$2
        local CONFIGURE_TARGET=$3
        local INSTALL_DIR="${BUILD_DIR}/${ARCH}-${PLATFORM}"

        log "Building for iOS: ${PLATFORM} (${ARCH})"

        export SDKROOT=$(xcrun --sdk ${PLATFORM} --show-sdk-path)
        export CC=$(xcrun --find -sdk ${PLATFORM} cc)
        export CFLAGS="-arch ${ARCH} -pipe -Os -isysroot ${SDKROOT} -miphoneos-version-min=${MIN_IOS_SDK_VERSION}"
        export LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT}"

        pushd "${SOURCE_DIR}" > /dev/null
        ./Configure ${CONFIGURE_TARGET} no-shared no-asm --prefix="${INSTALL_DIR}"
        make clean
        make -j
        make install_sw
        popd > /dev/null

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/"
    }

    # Build for all required iOS architectures
    build_ios_arch "arm64" "iphoneos" "ios64-cross"
    build_ios_arch "x86_64" "iphonesimulator" "iossimulator-xcrun"
    build_ios_arch "arm64" "iphonesimulator" "iossimulator-xcrun"

    #log "Creating XCFrameworks for iOS..."
    #mkdir -p "${OUTPUT_DIR}"
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/arm64-iphoneos/lib/libcrypto.a" -headers "${BUILD_DIR}/arm64-iphoneos/include" \
    #    -library "${BUILD_DIR}/x86_64-iphonesimulator/lib/libcrypto.a" -headers "${BUILD_DIR}/x86_64-iphonesimulator/include" \
    #    -library "${BUILD_DIR}/arm64-iphonesimulator/lib/libcrypto.a" -headers "${BUILD_DIR}/arm64-iphonesimulator/include" \
    #    -output "${OUTPUT_DIR}/libcrypto.xcframework"
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/arm64-iphoneos/lib/libssl.a" -headers "${BUILD_DIR}/arm64-iphoneos/include" \
    #    -library "${BUILD_DIR}/x86_64-iphonesimulator/lib/libssl.a" -headers "${BUILD_DIR}/x86_64-iphonesimulator/include" \
    #    -library "${BUILD_DIR}/arm64-iphonesimulator/lib/libssl.a" -headers "${BUILD_DIR}/arm64-iphonesimulator/include" \
    #    -output "${OUTPUT_DIR}/libssl.xcframework"
}

##
# Android Build Function
##
build_android() {
    log "Starting Android build..."

    if [ -z "$ANDROID_NDK_ROOT" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
        echo "Error: ANDROID_NDK_ROOT is not set or is not a valid directory."
        exit 1
    fi
    local TOOLCHAIN_PATH="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"

    # Function to build a specific Android architecture
    build_android_arch() {
        local ARCH_NAME=$1
        local CONFIGURE_TARGET=$2
        local TOOLCHAIN_PREFIX=$3
        local INSTALL_DIR="${BUILD_DIR}/${ARCH_NAME}"

        log "Building for Android: ${ARCH_NAME}"

        export PATH="${TOOLCHAIN_PATH}/bin:$PATH"
        export CC="${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}-linux-android${ANDROID_API_LEVEL}-clang"
        export CXX="${TOOLCHAIN_PATH}/bin/${TOOLCHAIN_PREFIX}-linux-android${ANDROID_API_LEVEL}-clang++"

        pushd "${SOURCE_DIR}" > /dev/null
        ./Configure ${CONFIGURE_TARGET} no-shared no-asm -D__ANDROID_API__=${ANDROID_API_LEVEL} --prefix="${INSTALL_DIR}"
        make clean
        make -j
        make install_sw
        popd > /dev/null

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH_NAME}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH_NAME}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH_NAME}/"
    }

    # Build for all required Android architectures
    build_android_arch "arm64-v8a" "android-arm64" "aarch64"
    build_android_arch "armeabi-v7a" "android-arm" "armv7a"
    #build_android_arch "x86_64" "android-x86_64" "x86_64"
    #build_android_arch "x86" "android-x86" "i686"
}

##
# macOS Build Function
##
build_macos() {
    log "Starting macOS build..."

    # Function to build a specific macOS architecture
    build_macos_arch() {
        local ARCH=$1
        local CONFIGURE_TARGET=$2
        local INSTALL_DIR="${BUILD_DIR}/${ARCH}"

        log "Building for macOS: ${ARCH}"

        # Explicitly set the SDK path to avoid header issues
        local SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
        export CC=$(xcrun --find cc)
        export CFLAGS="-arch ${ARCH} -pipe -Os -isysroot ${SDKROOT}"
        export LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT}"

        pushd "${SOURCE_DIR}" > /dev/null
        ./Configure ${CONFIGURE_TARGET} no-shared --prefix="${INSTALL_DIR}"
        make clean
        make -j
        make install_sw
        popd > /dev/null

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}/"
    }

    # Build for Intel and Apple Silicon
    #build_macos_arch "x86_64" "darwin64-x86_64-cc"
    build_macos_arch "arm64" "darwin64-arm64-cc"

    #log "Creating universal binaries and XCFramework for macOS..."
    #mkdir -p "${OUTPUT_DIR}"
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/x86_64/lib/libcrypto.a" -headers "${BUILD_DIR}/x86_64/include" \
    #    -library "${BUILD_DIR}/arm64/lib/libcrypto.a" -headers "${BUILD_DIR}/arm64/include" \
    #    -output "${OUTPUT_DIR}/libcrypto.xcframework"
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/x86_64/lib/libssl.a" -headers "${BUILD_DIR}/x86_64/include" \
    #    -library "${BUILD_DIR}/arm64/lib/libssl.a" -headers "${BUILD_DIR}/arm64/include" \
    #    -output "${OUTPUT_DIR}/libssl.xcframework"
}

##
# Linux Build Function
##
build_linux() {
    log "Starting Linux build for x86_64 and arm64..."

    # Function to build a specific Linux architecture
    build_linux_arch() {
        local ARCH=$1
        local CONFIGURE_TARGET=$2
        local CROSS_COMPILE_PREFIX=$3
        local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"

        log "Building for Linux: ${ARCH}"
        
        local CONFIGURE_FLAGS="no-shared --prefix=${INSTALL_DIR} --openssldir=${INSTALL_DIR}"
        if [ -n "${CROSS_COMPILE_PREFIX}" ]; then
            CONFIGURE_FLAGS="${CONFIGURE_FLAGS} --cross-compile-prefix=${CROSS_COMPILE_PREFIX}"
        fi

        pushd "${SOURCE_DIR}" > /dev/null
        # ./Configure is used for cross-compilation, ./config for native
        if [ -n "${CROSS_COMPILE_PREFIX}" ]; then
            ./Configure ${CONFIGURE_TARGET} ${CONFIGURE_FLAGS}
        else
            ./config ${CONFIGURE_FLAGS}
        fi
        
        make clean
        make -j
        make install_sw
        popd > /dev/null
    }

    # Determine host architecture to decide if we need to cross-compile
    HOST_ARCH=$(uname -m)

    # Build for x86_64
    if [ "$HOST_ARCH" = "x86_64" ]; then
        build_linux_arch "x86_64" "linux-x86_64" ""
    else
        # Assuming host is arm64, cross-compile for x86_64
        build_linux_arch "x86_64" "linux-x86_64" "x86_64-linux-gnu-"
    fi

    # Build for arm64 (aarch64)
    #if [ "$HOST_ARCH" = "aarch64" ]; then
    #    build_linux_arch "arm64" "linux-aarch64" ""
    #else
    #    # Assuming host is x86_64, cross-compile for arm64
    #    build_linux_arch "arm64" "linux-aarch64" "aarch64-linux-gnu-"
    #fi
}

# --- Main Execution ---
if [ -z "$TARGET_PLATFORM" ]; then
    echo "Error: No platform specified."
    echo "Usage: $0 <ios|android|macos|linux>"
    exit 1
fi

clone_openssl

# Clean and create directories
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

case $TARGET_PLATFORM in
    ios)
        build_ios
        ;;
    android)
        build_android
        ;;
    macos)
        build_macos
        ;;
    linux)
        build_linux
        ;;
    *)
        echo "Error: Unsupported platform '$TARGET_PLATFORM'."
        echo "Supported platforms are: ios, android, macos, linux"
        exit 1
        ;;
esac

log "Cleaning up intermediate build directory..."
rm -rf "${BUILD_DIR}"

log "Build for ${TARGET_PLATFORM} complete. Output is in '${OUTPUT_DIR}'"
