#!/bin/bash

# Shared directory for downloads
FIREFOX_DOWNLOADS="Downloads"
# Developer mode - Drop into a shell after firefox runs (or fails)
DEBUG_MODE=1
# Apply patches in patches/ directory?
APPLY_PATCHES=1
# name of docker image and container to create
DOCKER_IMAGE="firefox-build-and-run"
DOCKER_CONTAINER="firefox-build-and-run"

# Parallel build jobs. Some jobs will take ~1GB memory or more, so don't go 
# crazy or you may end up with strange build failures caused by OOM. If no
# value is passed into this script, then we'll try to calculate a reasonable
# value based on CPU threads and available memory.
# TODO
JOBS=48

# Changeset (tag, bookmark, or commit) to build
if [ -n "$FIREFOX_RELEASE" ]; then
	FIREFOX_RELEASE="central"
fi
# Path to local copy of firefox repo. See README.md for more information
# about using local sources.
if [ -n "$LOCAL_SRC" ]; then
	IN_CONTAINER_SRC="/var/local_src"
	LOCAL_SRC_MOUNT_OPT="--mount type=bind,target=${IN_CONTAINER_SRC},src=${LOCAL_SRC}"
	LOCAL_SRC="$IN_CONTAINER_SRC"
else
	LOCAL_SRC_MOUNT_OPT=""
fi

# X11 stuff to share with container
# The ROS wiki has good examples: http://wiki.ros.org/docker/Tutorials/GUI
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth

docker image inspect "$DOCKER_IMAGE" >/dev/null
if [ $? -ne 0 ]; then
	echo "Building $DOCKER_IMAGE"
	docker build -t "$DOCKER_IMAGE" --build-arg UID=$(id -u) --build-arg GID=$(id -g) .
fi

if [ ! -d "$FIREFOX_DOWNLOADS" ]; then
	mkdir -p "$FIREFOX_DOWNLOADS"
fi
echo "Downloads will be located in: $FIREFOX_DOWNLOADS"
# This will be bind mounted, so it must be absolute
FIREFOX_DOWNLOADS="$(realpath $FIREFOX_DOWNLOADS)"

touch ${XAUTH}
xauth nlist ${DISPLAY} | sed -e 's/^..../ffff/' | uniq | xauth -f ${XAUTH} nmerge -

DISPLAY2=$(echo $DISPLAY | sed s/localhost//)
if [ $DISPLAY2 != $DISPLAY ]
then
        DISPLAY=$DISPLAY2
        xauth nlist ${DISPLAY} | sed -e 's/^..../ffff/' | uniq | xauth -f ${XAUTH} nmerge -
fi

docker run -ti \
        --name "$DOCKER_CONTAINER" \
        --user firefox \
        --network=host \
        --mount type=bind,target=/home/firefox/Downloads,src=${FIREFOX_DOWNLOADS} \
		$LOCAL_SRC_MOUNT_OPT \
        -v ${XSOCK}:${XSOCK} \
        -v ${XAUTH}:${XAUTH} \
        -e XAUTHORITY=${XAUTH} \
        -e DISPLAY=${DISPLAY} \
		-e APPLY_PATCHES=${APPLY_PATCHES} \
		-e FIREFOX_RELEASE=${FIREFOX_RELEASE} \
		-e DEBUG_MODE=${DEBUG_MODE} \
		-e LOCAL_SRC=${LOCAL_SRC} \
		-e JOBS=${JOBS} \
		"$DOCKER_IMAGE"
