#!/bin/bash

set -eu -o pipefail

function show_help() {
cat << EOF
Usage: ndk-slim.sh [OPTIONS]
Options:
  --remove-apis
    Remove any api levels other than the one specified by the
    \$ANDROID_API environment variable.
  --remove-arch ARCH
    Remove all files used for building for given architecture.
    This option can be specified multiple times.
  --remove-man
    Remove man pages and other documentation files.
  --verbose
    Print names of removed files.
  --quiet
    Do not print names of removed files (default).
EOF
}

# -- Parge args

ARG_ARCH_AARCH64=0
ARG_ARCH_ARM=0
ARG_ARCH_X86_64=0
ARG_ARCH_X86=0
ARG_APIS=0
ARG_MAN=0
VERBOSE=0

while [[ "$#" -gt 0 ]]; do
	if [[ "$1" == "--help" ]]; then
		show_help
		exit
	elif [[ "$1" == "--remove-apis" ]]; then
		ARG_APIS=1
	elif [[ "$1" == "--remove-arch" ]]; then
		if [[ "$#" -lt 2 ]]; then
			echo "ndk-slim.sh: The \"remove-arch\" mode requires an argument" >&2
			exit 1
		elif [[ "${2}" == "aarch64" ]]; then
			ARG_ARCH_AARCH64=1
		elif [[ "${2}" == "arm" ]]; then
			ARG_ARCH_ARM=1
		elif [[ "${2}" == "x86_64" ]]; then
			ARG_ARCH_X86_64=1
		elif [[ "${2}" == "x86" ]]; then
			ARG_ARCH_X86=1
		else
			echo "ndk-slim.sh: The argument to \"remove-arch\" must be one of \"aarch64\", \"arm\", \"x86_64\" or \"x86\"" >&2
			exit 1
		fi
		shift 1
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

if [[ "${ARG_APIS}" -eq 0 ]] && [[ "${ARG_ARCH_AARCH64}" -eq 0 ]] && [[ "${ARG_ARCH_ARM}" -eq 0 ]] && [[ "${ARG_ARCH_X86_64}" -eq 0 ]] && [[ "${ARG_ARCH_X86}" -eq 0 ]] && [[ "${ARG_MAN}" -eq 0 ]]; then
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

# -- Arch removal
# TODO: Take a look at the file names and figure out some way to convert this
#       from 4 separate cases to 1 case with parameters.

if [[ "${ARG_ARCH_AARCH64}" -eq 1 ]]; then
	rm "${RM_FLAGS}" -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/aarch64-linux-android-* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/aarch64-linux-android*-clang* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux"/libclang_rt.*-aarch64-android.* \
		# Individual files first.

	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/build/core/toolchains/aarch64-linux-android-clang/" \
		"${NDK_PATH}/prebuilt/android-arm64/" \
		"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/" \
		"${NDK_PATH}/sources/third_party/vulkan/src/build-android/jniLibs/arm64-v8a/" \
		"${NDK_PATH}/sysroot/usr/include/aarch64-linux-android/" \
		"${NDK_PATH}/sysroot/usr/lib/aarch64-linux-android/" \
		"${NDK_PATH}/toolchains/aarch64-linux-android-4.9/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/aarch64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib/gcc/aarch64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux/aarch64/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/aarch64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/test/aarch64/" \
		"${NDK_PATH}/toolchains/renderscript/prebuilt/linux-x86_64/platform/arm64/" \
		# Directories next.
fi

if [[ "${ARG_ARCH_ARM}" -eq 1 ]]; then
	rm "${RM_FLAGS}" -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux"/libclang_rt.*-arm-android.* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/arm-linux-androideabi-* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/armv7a-linux-androideabi*-clang* \
		# Individual files first.

	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/build/core/toolchains/arm-linux-androideabi-clang/" \
		"${NDK_PATH}/prebuilt/android-arm/" \
		"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/armeabi-v7a/" \
		"${NDK_PATH}/sources/cxx-stl/llvm-libc++abi/test/native/arm-linux-eabi/" \
		"${NDK_PATH}/sources/third_party/vulkan/src/build-android/jniLibs/armeabi-v7a/" \
		"${NDK_PATH}/sysroot/usr/include/arm-linux-androideabi/" \
		"${NDK_PATH}/sysroot/usr/lib/arm-linux-androideabi/" \
		"${NDK_PATH}/toolchains/arm-linux-androideabi-4.9/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/arm-linux-androideabi/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib/gcc/arm-linux-androideabi/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux/arm/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/arm-linux-androideabi/ "\
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/test/arm/" \
		"${NDK_PATH}/toolchains/renderscript/prebuilt/linux-x86_64/platform/arm/" \
		# Directories next.
fi

if [[ "${ARG_ARCH_X86_64}" -eq 1 ]]; then
	rm "${RM_FLAGS}" -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux"/libclang_rt.*-x86_64-android.* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/x86_64-linux-android-* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/x86_64-linux-android*-clang* \
		# Individual files first.

	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/build/core/toolchains/x86_64-clang/" \
		"${NDK_PATH}/prebuilt/android-x86_64/" \
		"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/x86_64/" \
		"${NDK_PATH}/sources/third_party/vulkan/src/build-android/jniLibs/x86_64/" \
		"${NDK_PATH}/sysroot/usr/include/x86_64-linux-android/" \
		"${NDK_PATH}/sysroot/usr/lib/x86_64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib/gcc/x86_64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux/x86_64/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/x86_64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/x86_64-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/x86_64-linux-android/" \
		"${NDK_PATH}/toolchains/renderscript/prebuilt/linux-x86_64/platform/x86_64/" \
		"${NDK_PATH}/toolchains/x86_64-4.9/" \
		# Directories next.
fi

if [[ "${ARG_ARCH_X86}" -eq 1 ]]; then
	rm "${RM_FLAGS}" -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux"/libclang_rt.*-i686-android.* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"/i686-linux-android-* \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/"i686-linux-android*-clang* \
		# Individual files first.

	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/build/core/toolchains/x86-clang/" \
		"${NDK_PATH}/prebuilt/android-x86/" \
		"${NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/x86/" \
		"${NDK_PATH}/sources/third_party/vulkan/src/build-android/jniLibs/x86/" \
		"${NDK_PATH}/sysroot/usr/include/i686-linux-android/" \
		"${NDK_PATH}/sysroot/usr/lib/i686-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/i686-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib/gcc/i686-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/9.0.8/lib/linux/i386/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/i686-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/i686-linux-android/" \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/test/i686/" \
		"${NDK_PATH}/toolchains/renderscript/prebuilt/linux-x86_64/platform/x86/" \
		"${NDK_PATH}/toolchains/x86-4.9/" \
		# Directories next.
fi

# -- Man pages removal

if [[ "${ARG_MAN}" -gt 0 ]]; then
	rm "${RM_FLAGS}" -r -- \
		"${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/share/man/" \
		"${NDK_PATH}/toolchains/x86-4.9/prebuilt/linux-x86_64/share/man/" \
		# Don't need no man to tell me what to do.
fi
