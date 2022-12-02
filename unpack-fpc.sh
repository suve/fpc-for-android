#!/bin/bash

set -eu -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -- Parse args

if [[ "$#" -ne 2 ]]; then
	echo "Usage: unpack-fpc.sh BUILD_DIR FPC_VERSION" >&2
	exit 1
fi

BUILD_DIR="$1"
FPC_VERSION="$2"

# -- Verify args

ARCHIVE_NAME="fpcbuild-${FPC_VERSION}.tar.gz"
ARCHIVE_PATH="${SCRIPT_DIR}/${ARCHIVE_NAME}"
if [[ ! -f "${ARCHIVE_PATH}" ]]; then
	echo "Error: No \"fpcbuild-${FPC_VERSION}.tar.gz\" file found" >&2
	exit 1
fi

# -- Unpack

cd "${BUILD_DIR}"
if [[ ! -d "fpcbuild-${FPC_VERSION}" ]]; then
	tar xzf "${ARCHIVE_PATH}"
	for PATCH in "${SCRIPT_DIR}"/*.patch; do
		patch -p1 -d "fpcbuild-${FPC_VERSION}/fpcsrc" < "${PATCH}"
	done
fi

