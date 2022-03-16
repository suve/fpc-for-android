#!/bin/bash

set -eu -o pipefail

# -- Check args

if [[ "$#" -ne 2 ]]; then
	echo "Usage: build-fpc.sh BUILD_DIR FPC_VERSION" >&2
	exit 1
fi

BUILD_DIR="$1"
FPC_VERSION="$2"

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

NEW_FPC="${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc/compiler/ppcx64"

cd "${BUILD_DIR}/fpcbuild-${FPC_VERSION}/fpcsrc"
make clean

echo "====----> compiler_cycle"
make OPT="-gl" compiler_cycle

echo "====----> RTL"
make FPC="${NEW_FPC}" OPT="-gl" rtl_clean rtl_smart

echo "====----> packages"
make FPC="${NEW_FPC}" OPT="-gl" packages_smart

echo "====----> install"
mkdir -p /opt/fpc/usr
make install INSTALL_PREFIX=/opt/fpc/usr
ln -sr "/opt/fpc/usr/lib/fpc/${FPC_VERSION}/ppcx64" /opt/fpc/usr/bin/ppcx64

