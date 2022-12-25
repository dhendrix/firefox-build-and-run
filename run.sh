#!/bin/bash

# Shared directory for downloads
FIREFOX_DOWNLOADS="./Downloads"
# Developer mode - Drop into a shell after firefox runs (or fails)
DEBUG_MODE=0
# Relative path to patches which will be applied to firefox
PATCHES="patches/$(uname -m)"
# Name of docker image and container to create
DOCKER_IMAGE="firefox-build-and-run"
DOCKER_CONTAINER="firefox-build-and-run"
# Default release to build
FIREFOX_RELEASE="central"
# Path to sources. If empty, Firefox will be cloned in the container.
FIREFOX_SRC=""

# Parallel build jobs. Some jobs will take ~1GB memory or more, so don't go 
# crazy or you may end up with strange build failures caused by OOM. If no
# value is passed into this script, then we'll try to calculate a reasonable
# value based on CPU threads and available memory.
# TODO
JOBS=48

#
# Command-line parsing (loosely based on coreboot's buildgcc script)
#

myhelp()
{
	printf "Options:\n"
	printf "    [-c|--container]       name of Docker container (default: $DOCKER_CONTAINER)\n"
	printf "    [-d|--debug]           debug mode (default: $DEBUG_MODE)\n"
	printf "    [-D|--downloads]       path of downloads directory shared with container (default: $FIREFOX_DOWNLOADS)\n"
	printf "    [-h|--help]            print this help menu\n"
	printf "    [-j|--jobs]            number of concurrent build jobs to run (default: $JOBS)\n"
	printf "    [-p|--patches]         alternative path to patches (default: $PATCHES)\n"
	printf "    [-r|--release]         Firefox release (tag, bookmark, or commit) to build (default: $FIREFOX_RELEASE)\n"
	printf "    [-s|--src]             path to cached Firefox sources, if desired (default: none, clone Firefox)\n"
}

# Look if we have getopt. If not, build it.
export PATH=$PATH:.
getopt - > /dev/null 2>/dev/null || gcc -o getopt getopt.c

# parse parameters.. try to find out whether we're running GNU getopt
getoptbrand="$(getopt -V 2>/dev/null | sed -e '1!d' -e 's,^\(......\).*,\1,')"
shortopts="c:D:dhi:j:p:s:r:"
if [ "${getoptbrand}" = "getopt" ]; then
	# Detected GNU getopt that supports long options.
	args=$(getopt -l container:,debug,downloads:,help,image:,jobs:,patches:,release:,src: -o "$shortopts" -- "$@")
	getopt_ret=$?
	eval set -- "$args"
else
	# Detected non-GNU getopt
	args=$(getopt "$shortopts" $*)
	getopt_ret=$?
	# shellcheck disable=SC2086
	set -- $args
fi

if [ $getopt_ret != 0 ]; then
	myhelp
	exit 1
fi

while true ; do
        case "$1" in
		-c|--container)	shift; DOCKER_CONTAINER="$1"; shift;;
		-d|--debug)		shift; DEBUG_MODE=1;;
		-D|--downloads)	shift; FIREFOX_DOWNLOADS="$1"; shift;;
		-h|--help)		shift; myhelp; exit 0;;
		-j|--jobs)		shift; JOBS="$1"; shift;;
		-p|--patches)	shift; PATCHES="$1"; shift;;
		-r|--release)	shift; FIREFOX_RELEASE="$1"; shift;;
		-s|--src)		shift; FIREFOX_SRC="$1"; shift;;
		--)		shift; break;;
		*)		break;;
	esac
done

if [ $# -gt 0 ]; then
	printf "Excessive arguments: $*\n"
	myhelp
	exit 1
fi

# Path to local copy of firefox repo. See README.md for more information
# about using local sources.
if [ -n "$FIREFOX_SRC" ]; then
	IN_CONTAINER_SRC="/var/firefox_src"
	FIREFOX_SRC_MOUNT_OPT="--mount type=bind,target=${IN_CONTAINER_SRC},src=${FIREFOX_SRC}"
	FIREFOX_SRC="$IN_CONTAINER_SRC"
else
	FIREFOX_SRC_MOUNT_OPT=""
fi

if [ ! -d "$PATCHES" ]; then
	echo "Patches directory \"$PATCHES\" does not exist"
	exit 1
fi


echo "Using the following options:"
echo "container: $DOCKER_CONTAINER"
echo "debug mode: $DEBUG_MODE"
echo "downloads: $FIREFOX_DOWNLOADS"
echo "jobs: $JOBS"
echo "patches: $PATCHES"
echo "release: $RELEASE"
echo "src: $SRC"

docker image inspect "$DOCKER_IMAGE" >/dev/null
if [ $? -ne 0 ]; then
	echo "Building $DOCKER_IMAGE"
	docker build -t "$DOCKER_IMAGE" --build-arg UID=$(id -u) --build-arg GID=$(id -g) .
fi

if [ ! -d "$FIREFOX_DOWNLOADS" ]; then
	mkdir -p "$FIREFOX_DOWNLOADS"
fi
# This will be bind mounted, so it must be absolute
FIREFOX_DOWNLOADS="$(realpath $FIREFOX_DOWNLOADS)"

# X11 stuff to share with container
# The ROS wiki has good examples: http://wiki.ros.org/docker/Tutorials/GUI
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth

touch ${XAUTH}
xauth nlist ${DISPLAY} | sed -e 's/^..../ffff/' | uniq | xauth -f ${XAUTH} nmerge -

docker run -ti \
        --name "$DOCKER_CONTAINER" \
        --user firefox \
        --network=host \
        --mount type=bind,target=/home/firefox/Downloads,src=${FIREFOX_DOWNLOADS} \
		$FIREFOX_SRC_MOUNT_OPT \
        -v ${XSOCK}:${XSOCK} \
        -v ${XAUTH}:${XAUTH} \
        -e XAUTHORITY=${XAUTH} \
        -e DISPLAY=${DISPLAY} \
		-e PATCHES=${PATCHES} \
		-e FIREFOX_RELEASE=${FIREFOX_RELEASE} \
		-e DEBUG_MODE=${DEBUG_MODE} \
		-e FIREFOX_SRC=${FIREFOX_SRC} \
		-e JOBS=${JOBS} \
		"$DOCKER_IMAGE"
