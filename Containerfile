FROM docker.io/ubuntu:20.04 AS build

ENV DEBIAN_FRONTEND noninteractive
RUN \
	apt update && \
	apt install -y \
		fpc gdb zip

COPY fpcbuild-3.2.2.tar.gz /build/
COPY build-fpc.sh build-fpcross.sh /scripts/
RUN /scripts/build-fpc.sh /build 3.2.2

COPY android-ndk-r21d.zip /opt
RUN \
	cd /opt && \
	mkdir -p /opt/android && \
	unzip android-ndk-r21d.zip && \
	mv android-ndk-r21d/ /opt/android/ndk && \
	rm android-ndk-r21d.zip

ENV ANDROID_API=29
ENV ANDROID_NDK_ROOT=/opt/android/ndk/

RUN \
	/scripts/build-fpcross.sh /build 3.2.2 aarch64 && \
	/scripts/build-fpcross.sh /build 3.2.2 arm && \
	/scripts/build-fpcross.sh /build 3.2.2 x86_64

# -- Phase 2
# Start with a clean container

FROM docker.io/ubuntu:20.04

COPY --from=build /opt/android /opt/android
COPY --from=build /opt/fpc /

# Note: Strictly speaking, this isn't needed.
# The container is now able to build Android executables.
# It will, however, fail to build native executables because of missing ld.
ENV DEBIAN_FRONTEND noninteractive
RUN \
	apt update && \
	apt install -y binutils && \
	apt clean

