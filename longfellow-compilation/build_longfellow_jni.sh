#!/bin/bash

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status
set -x

TARGET_PLATFORM=$1

echo "TODO for $TARGET_PLATFORM"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OUTPUT_DIR="${SCRIPT_DIR}/output/longfellow-jni/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/longfellow-jni/${TARGET_PLATFORM}"

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

# --- Platform Build Functions ---

##
# macOS Build Function
##
build_macos() {
    log "Starting longfellow-jni macOS build..."

    build_macos_arch() {
	local ARCH=$1
	local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}"
	mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"
	
	pushd "${SCRIPT_DIR}/jnisrc"
	clang \
	    org_multipaz_mdoc_zkp_longfellow_LongfellowNatives.cc \
	    -I"${JAVA_HOME}/include" \
	    -I"${JAVA_HOME}/include/darwin" \
	    -I"${LONGFELLOW_ZK_PATH}/${ARCH}/include" \
	    -L"${LONGFELLOW_ZK_PATH}/${ARCH}/lib" -lmdoc_static \
	    -L"${OPENSSL_PATH}/${ARCH}/lib" -lcrypto \
	    -L"${ZSTD_PATH}/${ARCH}/lib" -lzstd \
	    -lstdc++ \
	    -shared -o "${OUTPUT_DIR}/${ARCH}/lib/libzkp.dylib" -install_name @rpath/libzkp.dylib
	strip "${OUTPUT_DIR}/${ARCH}/lib/libzkp.dylib"
	popd
    }

    #build_macos_arch "x86_64"
    build_macos_arch "arm64"
}

##
# Linux Build Function
##
build_linux() {
    log "Starting longfellow-jni Linux build..."

    build_linux_arch() {
	local ARCH=$1
	local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
	mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"

	local CC="/Users/zeuthen/homebrew/Cellar/x86_64-unknown-linux-gnu/13.3.0/bin/x86_64-linux-gnu-gcc"
	local STRIP="/Users/zeuthen/homebrew/Cellar/x86_64-unknown-linux-gnu/13.3.0/bin/x86_64-linux-gnu-strip"
	pushd "${SCRIPT_DIR}/jnisrc"
	$CC \
	    org_multipaz_mdoc_zkp_longfellow_LongfellowNatives.cc \
	    -I"${JAVA_HOME}/include" \
	    -I"${JAVA_HOME}/include/darwin" \
	    -I"${LONGFELLOW_ZK_PATH}/${ARCH}/include" \
	    -L"${LONGFELLOW_ZK_PATH}/${ARCH}/lib" -lmdoc_static \
	    -L"${OPENSSL_PATH}/${ARCH}/lib64" -lcrypto \
	    -L"${ZSTD_PATH}/${ARCH}/lib" -lzstd \
	    -lstdc++ -fPIC \
	    -shared -o "${OUTPUT_DIR}/${ARCH}/lib/libzkp.so" 
	$STRIP "${OUTPUT_DIR}/${ARCH}/lib/libzkp.so"
	popd
    }

    build_linux_arch "x86_64"    
}

##
# Android Build Function
##
build_android() {
    log "Starting longfellow-jni Android build..."

    build_android_arch() {
	local ARCH=$1
	local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
	mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"

	export SYSROOT="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/sysroot"
	case $ARCH in
	    "arm64-v8a")
		export CC="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang++"
		;;
	    "armeabi-v7a")
		export CC="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/armv7a-linux-androideabi21-clang++"
		;;
	    *)
		echo "Unsupported ARCH $ARCH"
		exit 1
		;;
	esac
	export STRIP="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip"

	pushd "${SCRIPT_DIR}/jnisrc"
	$CC \
	    --sysroot=$SYSROOT \
	    org_multipaz_mdoc_zkp_longfellow_LongfellowNatives.cc \
	    -I"${LONGFELLOW_ZK_PATH}/${ARCH}/include" \
	    -L"${LONGFELLOW_ZK_PATH}/${ARCH}/lib" -lmdoc_static \
	    -L"${OPENSSL_PATH}/${ARCH}/lib" -lcrypto \
	    -L"${ZSTD_PATH}/${ARCH}/lib" -lzstd \
	    -static-libstdc++ -fPIC \
	    -Wl,-z,max-page-size=16384 \
	    -shared -o "${OUTPUT_DIR}/${ARCH}/lib/libzkp.so"
	$STRIP "${OUTPUT_DIR}/${ARCH}/lib/libzkp.so"
	popd
    }

    build_android_arch "arm64-v8a"
    build_android_arch "armeabi-v7a"
}

# --- Main Execution ---

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
