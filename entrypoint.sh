#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0

if [ "$DEBUG_MODE" -eq 1 ]; then
	set +x
fi

ARCH="$(uname -m)"
HOME="/home/firefox/"
MOZDIR="mozilla-unified"

drop_to_shell() {
	/bin/bash
	exit 0
}

cd "$HOME"

#
# Try to run firefox in case this container is being re-used
#

echo "Checking if Firefox already exists in this container... "
if [ -d "$MOZDIR" ]; then
	echo "Found something! Trying it out..."
	cd "$MOZDIR"
	if ! ./mach run ; then
		if [ "$DEBUG_MODE" -eq 1 ]; then
			drop_to_shell
		fi
	else
		echo "Firefox found, but cannot run. This container may be corrupted."
		exit 1
	fi
fi
echo "Nope, proceeding to build Firefox."

#
# Clone or copy the repo
#

if ! which hg >/dev/null ; then
	echo "Installing Mercurial"
	python3 -m pip install --user mercurial
fi
source ${HOME}/.bashrc

# Get firefox sources
if [ -n "$FIREFOX_SRC" ]; then
	echo "Copying Firefox sources from $FIREFOX_SRC to ${MOZDIR}/"
	rsync -a "${FIREFOX_SRC}/" "${MOZDIR}/"
else
	echo "Cloning Firefox from upstream"
	sh clone_firefox.sh
fi

#
# Install build dependencies
#

if ! which node >/dev/null ; then
	echo "Installing Node"
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
	nvm install --lts
fi

if ! which rustc >/dev/null ; then
	echo "Installing Rust packages"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup.sh
	sh rustup.sh -y
	source "$HOME/.cargo/env"
	rustup target add wasm32-wasi
	cargo install just
	cargo install --force cbindgen
fi

#
# Pull, patch, and build.
#

cd "${MOZDIR}/"
# Copy and modify mozconfig
cp "${HOME}/mozconfigs/mozconfig-${ARCH}" mozconfig
# Set level of parallelism. Assume ~1GB per build job.

# parallel build jobs
echo "export CARGO_BUILD_JOBS=${JOBS}" >> mozconfig
echo "mk_add_options MOZ_MAKE_FLAGS=-j${JOBS}" >> mozconfig

# Bootstrapping needs to be done before patching since some patches touch build/
echo "Bootstrapping firefox"
hg pull
hg update -r "$FIREFOX_RELEASE"
# .mozbuild directory needs to exist or `mach bootstrap` will prompt for a
# location to store build state
mkdir "${HOME}/.mozbuild"
./mach bootstrap --no-system-changes --application-choice=browser

if [ -n "$PATCHES" ]; then
	if [ ! -d "$PATCHES" ]; then
		echo "Patches directory \"$PATCHES\" does not exist"
		exit 1
	fi
	echo "Applying patches from $PATCHES"
	for p in ${HOME}/patches/${ARCH}/*.diff ; do
		echo "Applying $p"
		patch -p1 < "$p"
	done
fi

echo "Configuring firefox"
./mach configure
echo "Building firefox"
./mach build

# At last!
./mach run

if [ "$DEBUG_MODE" -eq 1 ]; then
	drop_to_shell
fi

exit 1
