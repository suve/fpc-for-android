#!/bin/bash

set -eu -o pipefail
SCRIPT_DIR="$(pwd)/$(dirname "$0")"

# -- Check args

if [[ "$#" -ne 2 ]]; then
	echo "Usage: build-fpc.sh BUILD_DIR FPC_VERSION" >&2
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

echo "====----> install"
mkdir -p /opt/fpc/usr
make install INSTALL_PREFIX=/opt/fpc/usr
ln -sr "/opt/fpc/usr/lib/fpc/${FPC_VERSION}/ppcx64" /opt/fpc/usr/bin/ppcx64

# -- Create the FPC configuration file
mkdir -p /opt/fpc/etc
cat > /opt/fpc/etc/fpc.cfg <<EOF
-viewn
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget
-Fu/usr/lib/fpc/\$fpcversion/units/\$fpctarget/*
EOF

