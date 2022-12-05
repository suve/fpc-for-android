#!/bin/bash

set -eu -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

function print_usage() {
cat <<EOF
Usage: build-fpcross.sh [options] BUILD_DIR FPC_VERSION TARGET_ARCH
Options:
  --destdir DIR
    Specifies an alternative installation directory
    for system-wide installs. Does not affect single-user installs.
  --install <user, system>
    Install the compiler once the build is complete.
    Use "user" for a single-user install to \$HOME/fpc.
    or "system" for a system-wide install to /usr.
Required environment variables:
  - ANDROID_API - target Android API version
  - ANDROID_NDK_ROOT - Android NDK location
EOF
}

# -- Parse args

INSTALL=""
DESTDIR=""

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--install" ]]; then
		if [[ "$#" -eq 1 ]]; then
			echo "build-fpcross.sh: The --install option requires an argument" >&2
			exit 1
		fi
		if [[ "$2" != "user" ]] && [[ "$2" != "system" ]]; then
			echo "build-fpcross.sh: The argument to the --install option must be either \"user\" or \"system\"" >&2
			exit 1
		fi
		INSTALL="$2"
		shift 2
	elif [[ "$1" == "--destdir" ]]; then
		if [[ "$#" -eq 1 ]]; then
			echo "build-fpcross.sh: The --destdir option requires an argument" >&2
			exit 1
		fi
		DESTDIR="$2"
		shift 2
	elif [[ "$1" == "--help" ]]; then
		print_usage
		exit
	elif [[ "$1" == "--" ]]; then
		shift 1
		break
	else
		break
	fi
done

if [[ "$#" -lt 3 ]]; then
	print_usage >&2
	exit 1
fi

BUILD_DIR="$1"
FPC_VERSION="$2"
TARGET_ARCH="$3"

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

# -- Check args

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

# -- Unpack

"${SCRIPT_DIR}/unpack-fpc.sh" "${BUILD_DIR}" "${FPC_VERSION}"

# -- Perform build

function nativemake() {
	make -j "$(nproc)" \
		$@ \
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

if [[ "${INSTALL}" == "user" ]]; then
	NEW_FPC="${HOME}/fpc/lib/fpc/${FPC_VERSION}/ppcx64"
elif [[ "${INSTALL}" == "system" ]]; then
	NEW_FPC="${DESTDIR}/usr/lib/fpc/${FPC_VERSION}/ppcx64"
else
	NEW_FPC="/usr/lib/fpc/${FPC_VERSION}/ppcx64"
fi

if [[ -x "${NEW_FPC}" ]]; then
	nativemake FPC="${NEW_FPC}" compiler_cycle
else
	nativemake compiler_cycle
fi

echo "====----> RTL"
crossmake rtl_clean rtl_smart

echo "====----> packages"
crossmake packages_smart

# -- Install (or exit early)

if [[ -z "${INSTALL}" ]]; then
	exit
fi

echo "====----> install"

if [[ "${INSTALL}" == "user" ]]; then
	mkdir -p "${HOME}/fpc"
	make crossinstall \
		OS_TARGET=android CPU_TARGET="${TARGET_ARCH}" \
		INSTALL_PREFIX="${HOME}/fpc" INSTALL_BINDIR="${HOME}/fpc/bin" INSTALL_LIBDIR="${HOME}/fpc/lib"
	ln -sr "${HOME}/fpc/lib/fpc/${FPC_VERSION}/ppcross${PPC_NAME}" "${HOME}/fpc/bin/ppcross${PPC_NAME}"
else
	mkdir -p "${DESTDIR}/usr"
	make crossinstall \
		OS_TARGET=android CPU_TARGET="${TARGET_ARCH}" \
		INSTALL_PREFIX="${DESTDIR}/usr" INSTALL_BINDIR="${DESTDIR}/usr/bin" INSTALL_LIBDIR="${DESTDIR}/usr/lib"
	ln -sr "${DESTDIR}/usr/lib/fpc/${FPC_VERSION}/ppcross${PPC_NAME}" "${DESTDIR}/usr/bin/ppcross${PPC_NAME}"
fi


# -- Add CPU+OS specific-configuration to fpc.cfg

if [[ "${INSTALL}" == "user" ]]; then
	CONF_FILE="${HOME}/fpc/lib/fpc/etc/fpc.cfg"
else
	CONF_FILE="${DESTDIR}/etc/fpc.cfg"
fi

mkdir -p "$(dirname "${CONF_FILE}")"
cat >> "${CONF_FILE}" <<EOF
#ifdef android
#ifdef cpu${TARGET_ARCH}
-e${NDK_PATH}/toolchains/${TOOLCHAIN_DIR}/prebuilt/linux-x86_64/bin/
-Fl${NDK_PATH}/${LIBS_DIR}
#endif
#endif
EOF
