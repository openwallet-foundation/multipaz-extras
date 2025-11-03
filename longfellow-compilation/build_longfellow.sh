#!/bin/bash

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status
set -x

LONGFELLOW_TAG="v0.8.4"
ANDROID_API_LEVEL=21
MIN_IOS_SDK_VERSION="13.0"

# --- Script Setup ---
#if [ "$#" -ne 5 ]; then
#    echo "Usage: $0 <platform> <benchmark_path> <googletest_path> <openssl_path> <zstd_path>"
#    exit 1
#fi
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <platform>"
    exit 1
fi

TARGET_PLATFORM=$1
#BENCHMARK_PATH=$2
#GTEST_PATH=$3
#OPENSSL_PATH=$4
#ZSTD_PATH=$5

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/source/longfellow-zk"
OUTPUT_DIR="${SCRIPT_DIR}/output/longfellow-zk/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/longfellow-zk/${TARGET_PLATFORM}"

BASE_OUTPUT_DIR="${SCRIPT_DIR}/output"
BENCHMARK_PATH="${BASE_OUTPUT_DIR}/benchmark/${TARGET_PLATFORM}"
GTEST_PATH="${BASE_OUTPUT_DIR}/googletest/${TARGET_PLATFORM}"
OPENSSL_PATH="${BASE_OUTPUT_DIR}/openssl/${TARGET_PLATFORM}"
ZSTD_PATH="${BASE_OUTPUT_DIR}/zstd/${TARGET_PLATFORM}"


# --- Helper Functions ---
log() {
    echo ""
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
    echo ""
}

clone_longfellow() {
    if [ ! -d "${SOURCE_DIR}" ]; then
	log "Cloning longfellow-zk source code (commit ${LONGFELLOW_TAG})..."
	git clone https://github.com/google/longfellow-zk.git "${SOURCE_DIR}"
	cd "${SOURCE_DIR}"
	git reset --hard "${LONGFELLOW_TAG}"
	patch -p1 < "${SCRIPT_DIR}/longfellow-zk-${LONGFELLOW_TAG}.patch"
	cd "${SCRIPT_DIR}"
    fi
}

# --- Platform Build Functions ---

##
# iOS Build Function
##
build_ios() {
    log "Starting longfellow-zk iOS build..."

    build_ios_arch() {
	local ARCH=$1
	local PLATFORM=$2
	local SDKROOT=$(xcrun --sdk ${PLATFORM} --show-sdk-path)
	local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}-${PLATFORM}"
	local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}-${PLATFORM}"
	mkdir -p "${CMAKE_BUILD_DIR}"

	log "Building longfellow-zk for iOS: ${PLATFORM} (${ARCH})"

	cmake -S "${SOURCE_DIR}/lib" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
	      -DCMAKE_SYSTEM_NAME=iOS \
	      -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
	      -DCMAKE_OSX_SYSROOT=${SDKROOT} \
	      -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_IOS_SDK_VERSION} \
	      -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
	      -DBUILD_SHARED_LIBS=OFF \
	      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
	      -DCMAKE_SYSTEM_PROCESSOR="${ARCH}" \
	      -Dbenchmark_DIR="${BENCHMARK_PATH}/${ARCH}-${PLATFORM}/lib/cmake/benchmark" \
	      -DOPENSSL_ROOT_DIR="${OPENSSL_PATH}/${ARCH}-${PLATFORM}" \
	      -DGTest_ROOT_DIR="${GTEST_PATH}/${ARCH}-${PLATFORM}" \
	      -DGTest_DIR="${GTEST_PATH}/${ARCH}-${PLATFORM}/lib/cmake/GTest" \
	      -Dzstd_DIR="${ZSTD_PATH}/${ARCH}-${PLATFORM}/lib/cmake/zstd"

	make -C "${CMAKE_BUILD_DIR}" -j
	make -C "${CMAKE_BUILD_DIR}" install

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/"
    }

    build_ios_arch "arm64" "iphoneos"
    build_ios_arch "x86_64" "iphonesimulator"
    #build_ios_arch "arm64" "iphonesimulator"

    #log "Creating combined library and header output for iOS..."
    #mkdir -p "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/include"
    #cp -r "${BUILD_DIR}/install/arm64-iphoneos/include/"* "${OUTPUT_DIR}/include/"
    #lipo -create \
    #    "${BUILD_DIR}/install/arm64-iphoneos/lib/liblongfellow.a" \
    #    "${BUILD_DIR}/install/x86_64-iphonesimulator/lib/liblongfellow.a" \
    #    "${BUILD_DIR}/install/arm64-iphonesimulator/lib/liblongfellow.a" \
    #    -output "${OUTPUT_DIR}/lib/liblongfellow.a"
}

##
# Android Build Function
##
build_android() {
    log "Starting longfellow-zk Android build..."

    if [ -z "$ANDROID_NDK_ROOT" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
	echo "Error: ANDROID_NDK_ROOT is not set or is not a valid directory."
	exit 1
    fi

    build_android_arch() {
	local ARCH=$1
	local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
	local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
	local TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"

	log "Building longfellow-zk for Android: ${ARCH}"
	mkdir -p "${CMAKE_BUILD_DIR}"

	cmake -S "${SOURCE_DIR}/lib" -B "${CMAKE_BUILD_DIR}" \
	      -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
	      -DANDROID_ABI=${ARCH} \
	      -DANDROID_PLATFORM=android-${ANDROID_API_LEVEL} \
	      -DANDROID_STL=c++_static \
	      -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
	      -DBUILD_SHARED_LIBS=OFF \
	      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
	      -Dbenchmark_DIR="${BENCHMARK_PATH}/${ARCH}/lib/cmake/benchmark" \
	      -DOPENSSL_ROOT_DIR="${OPENSSL_PATH}/${ARCH}" \
	      -DGTest_ROOT_DIR="${GTEST_PATH}/${ARCH}" \
	      -DGTest_DIR="${GTEST_PATH}/${ARCH}/lib/cmake/GTest" \
	      -Dzstd_DIR="${ZSTD_PATH}/${ARCH}/lib/cmake/zstd"

	cmake --build "${CMAKE_BUILD_DIR}"
	cmake --install "${CMAKE_BUILD_DIR}"
    }

    build_android_arch "arm64-v8a"
    build_android_arch "armeabi-v7a"
    #build_android_arch "x86_64"
    #build_android_arch "x86"
}

##
# macOS Build Function
##
build_macos() {
    log "Starting longfellow-zk macOS build..."

    build_macos_arch() {
	local ARCH=$1
	local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
	local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}"
	mkdir -p "${CMAKE_BUILD_DIR}"

	log "Building longfellow-zk for macOS: ${ARCH}"
	local SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

	cmake -S "${SOURCE_DIR}/lib" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
	      -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
	      -DCMAKE_OSX_SYSROOT=${SDKROOT} \
	      -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
	      -DBUILD_SHARED_LIBS=OFF \
	      -DCMAKE_SYSTEM_NAME=Linux \
	      -DCMAKE_SYSTEM_PROCESSOR="${ARCH}" \
	      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
	      -Dbenchmark_DIR="${BENCHMARK_PATH}/${ARCH}/lib/cmake/benchmark" \
	      -DOPENSSL_ROOT_DIR="${OPENSSL_PATH}/${ARCH}" \
	      -DGTest_ROOT_DIR="${GTEST_PATH}/${ARCH}" \
	      -DGTest_DIR="${GTEST_PATH}/${ARCH}/lib/cmake/GTest" \
	      -Dzstd_DIR="${ZSTD_PATH}/${ARCH}/lib/cmake/zstd"

	make -C "${CMAKE_BUILD_DIR}" -j
	make -C "${CMAKE_BUILD_DIR}" install

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}/"
    }

    #build_macos_arch "x86_64"
    build_macos_arch "arm64"

    #log "Creating combined library and header output for macOS..."
    #mkdir -p "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/include"
    #cp -r "${BUILD_DIR}/install/arm64/include/"* "${OUTPUT_DIR}/include/"
    #lipo -create \
    #    "${BUILD_DIR}/install/x86_64/lib/liblongfellow.a" \
    #    "${BUILD_DIR}/install/arm64/lib/liblongfellow.a" \
    #    -output "${OUTPUT_DIR}/lib/liblongfellow.a"
}

##
# Linux Build Function
##
build_linux() {
    log "Starting longfellow-zk Linux build..."

    build_linux_arch() {
	local ARCH=$1
	local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
	local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
	local CMAKE_EXTRA_FLAGS=""

	log "Building longfellow-zk for Linux: ${ARCH}"
	mkdir -p "${CMAKE_BUILD_DIR}"

	if [ "$(uname -m)" != "$ARCH" ]; then
	    log "Cross-compiling for ${ARCH}..."
	    if [ "$ARCH" = "arm64" ]; then
		CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
	    elif [ "$ARCH" = "x86_64" ]; then
		CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++"
	    fi
	fi

	#export OPENSSL_ROOT_DIR="${OPENSSL_PATH}/${ARCH}"
	cmake -S "${SOURCE_DIR}/lib" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
	      -DCMAKE_BUILD_TYPE=Release \
	      -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
	      -DBUILD_SHARED_LIBS=OFF \
	      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
	      -DCMAKE_SYSTEM_NAME=Linux \
	      -DCMAKE_SYSTEM_PROCESSOR="${ARCH}" \
	      ${CMAKE_EXTRA_FLAGS} \
	      -DCMAKE_POSITION_INDEPENDENT_CODE="ON" \
	      -Dbenchmark_DIR="${BENCHMARK_PATH}/${ARCH}/lib/cmake/benchmark" \
	      -DOPENSSL_ROOT_DIR="${OPENSSL_PATH}/${ARCH}" \
	      -DGTest_ROOT_DIR="${GTEST_PATH}/${ARCH}" \
	      -DGTest_DIR="${GTEST_PATH}/${ARCH}/lib/cmake/GTest" \
	      -Dzstd_DIR="${ZSTD_PATH}/${ARCH}/lib/cmake/zstd"

	make -C "${CMAKE_BUILD_DIR}" -j1
	make -C "${CMAKE_BUILD_DIR}" install
    }

    build_linux_arch "x86_64"
    #build_linux_arch "arm64"
}

# --- Main Execution ---
clone_longfellow

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
