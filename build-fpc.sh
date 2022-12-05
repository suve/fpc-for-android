#!/bin/bash

set -eu -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

function print_usage() {
cat <<EOF
Usage: build-fpc.sh [options] BUILD_DIR FPC_VERSION
Options:
  --destdir DIR
    Specifies an alternative installation directory
    for system-wide installs. Does not affect single-user installs.
  --install <user, system>
    Install the compiler once the build is complete.
    Use "user" for a single-user install to "\$HOME/fpc".
    or "system" for a system-wide install to system root ("/").
EOF
}

# -- Parse args

INSTALL=""
DESTDIR=""

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--install" ]]; then
		if [[ "$#" -eq 1 ]]; then
			echo "build-fpc.sh: The --install option requires an argument" >&2
			exit 1
		fi
		if [[ "$2" != "user" ]] && [[ "$2" != "system" ]]; then
			echo "build-fpc.sh: The argument to the --install option must be either \"user\" or \"system\"" >&2
			exit 1
		fi
		INSTALL="$2"
		shift 2
	elif [[ "$1" == "--destdir" ]]; then
		if [[ "$#" -eq 1 ]]; then
			echo "build-fpc.sh: The --destdir option requires an argument" >&2
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

if [[ "$#" -lt 2 ]]; then
	print_usage >&2
	exit 1
fi

BUILD_DIR="$1"
FPC_VERSION="$2"

# -- Unpack

"${SCRIPT_DIR}/unpack-fpc.sh" "${BUILD_DIR}" "${FPC_VERSION}"

# -- Perform build

NEW_FPC="${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc/compiler/ppcx64"

cd "${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc"
make clean

echo "====----> compiler_cycle"
make -j "$(nproc)" OPT="-gl" compiler_cycle

echo "====----> RTL"
make -j "$(nproc)" FPC="${NEW_FPC}" OPT="-gl" rtl_clean rtl_smart

echo "====----> packages"
make -j "$(nproc)" FPC="${NEW_FPC}" OPT="-gl" packages_smart

# -- Install (or exit early)

if [[ -z "${INSTALL}" ]]; then
	exit
fi

echo "====----> install"

if [[ "${INSTALL}" == "user" ]]; then
	mkdir -p "${HOME}/fpc"
	make install INSTALL_PREFIX="${HOME}/fpc" INSTALL_BINDIR="${HOME}/fpc/bin" INSTALL_LIBDIR="${HOME}/fpc/lib"
	ln -sr "${HOME}/fpc/lib/fpc/${FPC_VERSION}/ppcx64" "${HOME}/fpc/bin/ppcx64"
else
	mkdir -p "${DESTDIR}/usr"
	make install INSTALL_PREFIX="${DESTDIR}/usr" INSTALL_BINDIR="${DESTDIR}/usr/bin" INSTALL_LIBDIR="${DESTDIR}/usr/lib"
	ln -sr "${DESTDIR}/usr/lib/fpc/${FPC_VERSION}/ppcx64" "${DESTDIR}/usr/bin/ppcx64"
fi

# -- Create the FPC configuration file

if [[ "${INSTALL}" == "user" ]]; then
	mkdir -p "${HOME}/fpc/lib/fpc/etc/"
	cat >> "${HOME}/fpc/lib/fpc/etc/fpc.cfg" << EOF
-viewn
-Fu${HOME}/fpc/lib/fpc/\$fpcversion/units/\$fpctarget
-Fu${HOME}/fpc/lib/fpc/\$fpcversion/units/\$fpctarget/*
EOF
else
	mkdir -p "${DESTDIR}/etc"
	cat >> "${DESTDIR}/etc/fpc.cfg" <<EOF
-viewn
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget/*
EOF
fi
