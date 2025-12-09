#!/bin/bash

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status
set -x

TARGET_PLATFORM=$1

echo "TODO for $TARGET_PLATFORM"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OUTPUT_DIR="${SCRIPT_DIR}/output/longfellow-ioswrapper/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/longfellow-ioswrapper/${TARGET_PLATFORM}"

JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-21-latest/Contents/Home/"

BASE_OUTPUT_DIR="${SCRIPT_DIR}/output"
BENCHMARK_PATH="${BASE_OUTPUT_DIR}/benchmark/${TARGET_PLATFORM}"
GTEST_PATH="${BASE_OUTPUT_DIR}/googletest/${TARGET_PLATFORM}"
OPENSSL_PATH="${BASE_OUTPUT_DIR}/openssl/${TARGET_PLATFORM}"
ZSTD_PATH="${BASE_OUTPUT_DIR}/zstd/${TARGET_PLATFORM}"
LONGFELLOW_ZK_PATH="${BASE_OUTPUT_DIR}/longfellow-zk/${TARGET_PLATFORM}"

# --- Helper Functions ---

log() {
    echo ""
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
    echo ""
}

##
# iOS Build Function
##

build_ios() {
    log "Starting longfellow-ioswrapper iOS build..."

    FRAMEWORK_NAME="MdocZk"
    WRAPPER_H="MdocZkWrapper.h"
    WRAPPER_M="MdocZkWrapper.m"
    C_HEADER="mdoc_zk.h"
    C_LIB_STATIC="libmdoc_static.a"
    DEVICE_ARCH="arm64"
    ARCH="arm64-iphoneos"

    pushd "${SCRIPT_DIR}/ioswrappersrc"
    clang \
        -x objective-c \
        -arch ${DEVICE_ARCH} \
        -fmodules \
        -c "${WRAPPER_M}" \
        -o "${BUILD_DIR}/${FRAMEWORK_NAME}.o" \
        -I. \
        -I"${LONGFELLOW_ZK_PATH}/${ARCH}/include" \
        -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
        -mios-version-min=13.0

    mkdir -p "${OUTPUT_DIR}/${ARCH}/${FRAMEWORK_NAME}.framework/"
    libtool -static \
        "${BUILD_DIR}/${FRAMEWORK_NAME}.o" \
        "${LONGFELLOW_ZK_PATH}/${ARCH}/lib/${C_LIB_STATIC}" \
        -o "${OUTPUT_DIR}/${ARCH}/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"

    mkdir -p "${OUTPUT_DIR}/${ARCH}/${FRAMEWORK_NAME}.framework/Headers/"
    cp "${LONGFELLOW_ZK_PATH}/${ARCH}/include/${C_HEADER}" "${OUTPUT_DIR}/${ARCH}/${FRAMEWORK_NAME}.framework/Headers/"
    cp "${WRAPPER_H}" "${OUTPUT_DIR}/${ARCH}/${FRAMEWORK_NAME}.framework/Headers/"

}

# --- Main Execution ---

# Clean and create directories
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

case $TARGET_PLATFORM in
    ios)
      build_ios
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
