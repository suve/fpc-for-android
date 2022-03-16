#!/bin/bash

set -eu -o pipefail

# -- Check args

if [[ "$#" -ne 3 ]]; then
	cat >&2 <<EOF
Usage: build-fpcross.sh BUILD_DIR FPC_VERSION TARGET_ARCH
Required environment variables:
  - ANDROID_API - target Android API version
  - ANDROID_NDK_ROOT - Android NDK location
EOF
	exit 1
fi

BUILD_DIR="$1"
FPC_VERSION="$2"
TARGET_ARCH="$3"

if [[ "${TARGET_ARCH}" == "aarch64" ]]; then
	PPC_NAME="a64"
	FPC_OPTS="-gl"
	TOOLCHAIN_DIR="aarch64-linux-android-4.9"
	LIBS_DIR="platforms/android-${ANDROID_API}/arch-arm64/usr/lib"
elif [[ "${TARGET_ARCH}" == "arm" ]]; then
	PPC_NAME="arm"
	FPC_OPTS="-gl -dFPC_ARMHF"
	TOOLCHAIN_DIR="arm-linux-androideabi-4.9"
	LIBS_DIR="platforms/android-${ANDROID_API}/arch-arm/usr/lib"
elif [[ "${TARGET_ARCH}" == "x86_64" ]]; then
	PPC_NAME="x64"
	FPC_OPTS="-gl"
	TOOLCHAIN_DIR="x86_64-4.9"
	LIBS_DIR="platforms/android-${ANDROID_API}/arch-x86_64/usr/lib64"
else
	echo "Error: Unsupported arch \"${TARGET_ARCH}\"" >&2
	exit 1
fi

# -- Check env vars

if [[ -z "${ANDROID_API+isset}" ]]; then
	echo "Error: \$ANDROID_API is unset" >&2
	exit 1
fi

NDK_PATH=""
if [[ ! -z "${ANDROID_NDK_ROOT+isset}" ]]; then
	NDK_PATH="${ANDROID_NDK_ROOT}"
elif [[ ! -z "${ANDROID_NDK_HOME+isset}" ]]; then
	NDK_PATH="${ANDROID_NDK_HOME}"
else
	echo "Error: Both \$ANDROID_NDK_ROOT and \$ANDROID_NDK_HOME are unset" >&2
	echo "Error: Unable to determine Android NDK location" >&2
	exit 1
fi

# -- Unpack

cd "${BUILD_DIR}"
if [[ ! -d "fpcbuild-${FPC_VERSION}" ]]; then
	if [[ -f "fpcbuild-${FPC_VERSION}.tar.gz" ]]; then
		tar xzf "fpcbuild-${FPC_VERSION}.tar.gz"
	else
		echo "Error: No \"fpcbuild-${FPC_VERSION}\" directory found" >&2
		echo "Error: No \"fpcbuild-${FPC_VERSION}.tar.gz\" file found" >&2
		exit 1
	fi
fi

# -- Perform build

function nativemake() {
	make $@ \
		NOGDB=1 \
		OS_TARGET="android" \
		CPU_TARGET="${TARGET_ARCH}" \
		CROSSOPT="${FPC_OPTS} -Fl${NDK_PATH}/${LIBS_DIR}" \
		NDK="${NDK_PATH}"
}

function crossmake() {
	nativemake $@ FPC="${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc/compiler/ppcross${PPC_NAME}"
}

# Add Android NDK toolchain to PATH
export PATH="${PATH}:${NDK_PATH}/toolchains/${TOOLCHAIN_DIR}/prebuilt/linux-x86_64/bin/"

cd "${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc"
make clean

echo "====----> compiler_cycle"
NEW_FPC="/opt/fpc/usr/lib/fpc/${FPC_VERSION}/ppcx64"
if [[ -x "${NEW_FPC}" ]]; then
	nativemake FPC="${NEW_FPC}" compiler_cycle
else
	nativemake compiler_cycle
fi

echo "====----> RTL"
crossmake rtl_clean rtl_smart

echo "====----> packages"
crossmake packages_smart

echo "====----> install"
mkdir -p /opt/fpc/usr
make crossinstall OS_TARGET=android CPU_TARGET="${TARGET_ARCH}" INSTALL_PREFIX=/opt/fpc/usr
ln -sr "/opt/fpc/usr/lib/fpc/${FPC_VERSION}/ppcross${PPC_NAME}" "/opt/fpc/usr/bin/ppcross${PPC_NAME}"

# -- Add CPU+OS specific-configuration to fpc.cfg
mkdir -p /opt/fpc/etc
cat >>/opt/fpc/etc/fpc.cfg <<EOF
#ifdef android
#ifdef cpu${TARGET_ARCH}
-e${NDK_PATH}/toolchains/${TOOLCHAIN_DIR}/prebuilt/linux-x86_64/bin/
-Fl${NDK_PATH}/${LIBS_DIR}
#endif
#endif
EOF
