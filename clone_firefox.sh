#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#
# This helper script will clone the firefox repo using steps taken from
# hg_clone_firefox() in bootstrap.py found here:
# https://firefox-source-docs.mozilla.org/setup/linux_build.html

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
