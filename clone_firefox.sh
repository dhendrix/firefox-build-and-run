#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#
# This helper script will clone the firefox repo using steps taken from
# hg_clone_firefox() in bootstrap.py found here:
# https://firefox-source-docs.mozilla.org/setup/linux_build.html
#
# Unlike bootstrap.py, it will *NOT* attempt to bootstrap Firefox. Bootstrapping
# sets up the Python virtual environment which makes it difficult to copy the
# source code to another location (e.g. in the container). See the following URL
# for more details:
# https://firefox-source-docs.mozilla.org/build/buildsystem/python.html#deficiencies

set -e

MOZDIR="mozilla-unified"

if [ -e "$MOZDIR" ]; then
	echo "$MOZDIR already exists, exiting" 
	exit 1
fi

mkdir -p "$MOZDIR"
pushd "$MOZDIR"

hg --config format.generaldelta=true init

cat > .hg/hgrc << EOF
[paths]
default = https://hg.mozilla.org/mozilla-unified

[format]
# This is necessary to keep performance in check
maxchainlen = 10000
EOF

hg pull https://hg.mozilla.org/mozilla-unified
hg update -r central
popd

set +e
