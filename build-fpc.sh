#!/bin/bash

set -eu -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

function print_usage() {
cat <<EOF
Usage: build-fpc.sh [options] BUILD_DIR FPC_VERSION
Options:
  --install INSTALL_DIR
    Install the compiler once the build is complete.
EOF
}

# -- Parse args

INSTALL_DIR=""

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--install" ]]; then
		if [[ "$#" -eq 1 ]]; then
			echo "build-fpc.sh: The --install option requires an argument" >&2
			exit 1
		fi
		INSTALL_DIR="$2"
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
make OPT="-gl" compiler_cycle

echo "====----> RTL"
make FPC="${NEW_FPC}" OPT="-gl" rtl_clean rtl_smart

echo "====----> packages"
make FPC="${NEW_FPC}" OPT="-gl" packages_smart

# -- Install (or exit early)

if [[ -z "${INSTALL_DIR}" ]]; then
	exit
fi

echo "====----> install"
mkdir -p "${INSTALL_DIR}/usr"
make install INSTALL_PREFIX="${INSTALL_DIR}/usr"
ln -sr "${INSTALL_DIR}/usr/lib/fpc/${FPC_VERSION}/ppcx64" "${INSTALL_DIR}/usr/bin/ppcx64"

# -- Create the FPC configuration file
mkdir -p "${INSTALL_DIR}/etc"
cat >> "${INSTALL_DIR}/etc/fpc.cfg" <<EOF
-viewn
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget/*
EOF

