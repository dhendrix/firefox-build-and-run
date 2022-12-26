# SPDX-License-Identifier: Apache-2.0
FROM fedora:38
LABEL maintainer="David Hendricks"

# uid and gid in container needs to match host owner of
# /tmp/.docker.xauth, so they must be passed as build arguments.
ARG UID
ARG GID

RUN yum update -y

RUN \
	yum groupinstall -y "C Development Tools and Libraries" && \
	yum groupinstall -y "GNOME Software Development"

# various other packages I think are needed for firefox...
RUN yum install -y \
	alsa-lib \
	alsa-lib-devel \
	alsa-tools \
	alternatives \
	bindgen \
	bzip2 \
	clang \
	dbus-glib-devel \
	gcc \
	glibc-static \
	gtk3-devel \
	libICE-devel \
	libSM-devel \
	libXcomposite-devel \
	libXcursor-devel \
	libXdamage-devel \
	libXrandr-devel \
	libXt-devel \
	libXtst-devel \
	libdrm-devel \
	libstdc++-static \
	libogg-devel \
	m4 \
	nasm \
	ninja-build \
	pango-devel \
	perl \
	perl-FindBin \
	psutils \
	pulseaudio-libs-devel \
	python3-devel \
	unzip \
	watchman \
	zstd

# Some unit tests need these
RUN yum install -y \
	libpciaccess \
	libpciaccess-devel \
	pciutils \
	pciutils-devel \
	pciutils-devel-static \
	pciutils-libs

# Nice to have for interactive shells, but not necessary for firefox
RUN yum install -y \
	less \
	patch \
	rsync \
	vim

RUN \
	groupadd -g $GID firefox && \
	useradd --create-home --uid $UID --gid $GID --comment="Firefox User" firefox

USER firefox
COPY --chown=firefox:firefox clone_firefox.sh /home/firefox/
COPY --chown=firefox:firefox mozconfigs/ /home/firefox/mozconfigs/
COPY --chown=firefox:firefox patches/ /home/firefox/patches/

COPY entrypoint.sh /sbin
ENTRYPOINT [ "/bin/sh", "/sbin/entrypoint.sh" ]
