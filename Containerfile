FROM docker.io/ubuntu:20.04 AS build

ENV DEBIAN_FRONTEND noninteractive
RUN \
	apt update && \
	apt install -y \
		fpc gdb zip

COPY android-ndk-r21d.zip /opt
RUN \
	cd /opt && \
	mkdir -p /opt/android && \
	unzip android-ndk-r21d.zip && \
	mv android-ndk-r21d/ /opt/android/ndk && \
	rm android-ndk-r21d.zip

ENV ANDROID_API=29
ENV ANDROID_NDK_ROOT=/opt/android/ndk/

COPY fpcbuild-3.2.2.tar.gz /build/
COPY build-fpc.sh /scripts/

RUN \
	/scripts/build-fpc.sh '/build' '3.2.2' aarch64 && \
	/scripts/build-fpc.sh '/build' '3.2.2' arm && \
	/scripts/build-fpc.sh '/build' '3.2.2' x86_64

