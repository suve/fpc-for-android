#!/bin/bash

set -eu -o pipefail

function show_help() {
cat << EOF
Usage: ndk-slim.sh [OPTIONS]
Options:
  --remove-apis
    Remove any api levels other than the one specified by the
    \$ANDROID_API environment variable.
  --remove-man
    Remove man pages and other documentation files.
  --verbose
    Print names of removed files.
  --quiet
    Do not print names of removed files (default).
EOF
}

# -- Parge args

ARG_APIS=0
ARG_MAN=0
VERBOSE=0

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--help" ]]; then
		show_help
		exit
	elif [[ "$1" == "--remove-apis" ]]; then
		ARG_APIS=1
	elif [[ "$1" == "--remove-man" ]]; then
		ARG_MAN=1
	elif [[ "$1" == "--verbose" ]]; then
		VERBOSE=1
	elif [[ "$1" == "--quiet" ]]; then
		VERBOSE=0
	else
		echo "Error: Unknown option \"${1}\"" >&2
		exit 1
	fi
	shift 1
done

# -- Verify args

if [[ "${ARG_APIS}" -eq 0 ]] && [[ "${ARG_MAN}" -eq 0 ]]; then
	show_help
	exit 1
fi

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

# -- Start slimming: APIs first

if [[ "${ARG_APIS}" -gt 0 ]]; then
	# TODO: Detect which platforms are present instead of hard-coding the range here
	for API in $(seq 16 35); do
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
fi

# -- Man pages removal

if [[ "${ARG_MAN}" -gt 0 ]]; then
	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/share/man/" \
		"${NDK_PATH}/toolchains/x86-4.9/prebuilt/linux-x86_64/share/man/" \
		# Don't need no man to tell me what to do.
fi
