#!/bin/bash

set -eu -o pipefail

# -- Check args

VERBOSE=0

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--verbose" ]]; then
		VERBOSE=1
	elif [[ "$1" == "--quiet" ]]; then
		VERBOSE=0
	else
		echo "Error: Unknown argument \"${1}\"" >&2
		exit 1
	fi
	shift 1
done

RM_FLAGS="-f"
if [[ "${VERBOSE}" -eq 1 ]]; then
	RM_FLAGS="${RM_FLAGS}v"
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

# -- Start slimming

# TODO: Detect which platforms are present instead of hard-coding the range here
for API in $(seq 16 33); do
	if [[ "${API}" -eq "${ANDROID_API}" ]]; then
		continue
	fi

	PLATFORM_DIR="${NDK_PATH}/platforms/android-${API}/"
	if [[ ! -d "${PLATFORM_DIR}" ]]; then
		continue
	fi

	for TARGET in aarch64-linux-android arm-linux-androideabi i686-linux-android x86_64-linux-android; do
		rm "${RM_FLAGS}" -r -- \
			"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${TARGET}/${API}/" \
		# This comment is here just so we can keep the trailing \ on the line above.
	done

	for TARGET in aarch64-linux-android armv7a-linux-androideabi i686-linux-android x86_64-linux-android; do
		rm "${RM_FLAGS}" -- \
			"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}${API}-clang++" \
			"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TARGET}${API}-clang" \
		# Don't mind me.
	done

	for TARGET in arm64-v8a armeabi-v7a x86 x86_64; do
		rm "${RM_FLAGS}" -- \
			"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/${TARGET}/libc++.a.${API}" \
			"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/${TARGET}/libc++.so.${API}" \
		# Same as before.
	done

	rm "${RM_FLAGS}" -r -- "${PLATFORM_DIR}"
done
