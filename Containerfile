FROM docker.io/ubuntu:20.04 AS build

RUN \
	export DEBIAN_FRONTEND=noninteractive && \
	apt update && \
	apt install -y fpc gdb zip

COPY fpcbuild-*.tar.gz *.patch *.sh /scripts/
RUN \
	mkdir -p build && \
	/scripts/build-fpc.sh --install /opt/fpc /build 3.2.2

ARG ANDROID_API
ENV ANDROID_API=${ANDROID_API:-21}
ENV ANDROID_NDK_ROOT=/opt/android/ndk-21d/

COPY android-ndk-r21d.zip /opt
RUN \
	cd /opt && \
	mkdir -p /opt/android && \
	unzip android-ndk-r21d.zip && \
	mv android-ndk-r21d/ /opt/android/ndk-21d && \
	rm android-ndk-r21d.zip && \
	/scripts/ndk-slim.sh --verbose

RUN \
	/scripts/build-fpcross.sh --install /opt/fpc /build 3.2.2 aarch64 && \
	/scripts/build-fpcross.sh --install /opt/fpc /build 3.2.2 arm && \
	/scripts/build-fpcross.sh --install /opt/fpc /build 3.2.2 x86_64

# -- Phase 2
# Start with a clean container

FROM docker.io/ubuntu:20.04

COPY --from=build /opt/android /opt/android
COPY --from=build /opt/fpc /

ARG ANDROID_API
ENV ANDROID_API=${ANDROID_API:-21}
ENV ANDROID_NDK_ROOT=/opt/android/ndk-21d/

# - binutils: not needed for Android, but required by fpc for linking native executables
# - file: used by ndk-build (though not strictly *required*)
# - make: required by ndk-build
RUN \
	export DEBIAN_FRONTEND=noninteractive && \
	apt update && \
	apt install -y binutils file make && \
	apt clean

