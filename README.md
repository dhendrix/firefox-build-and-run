# firefox-build-and-run
Build and run Firefox in a Docker container.

Initial target is ppc64le, but this should work for other architectures as well.

## Getting started

The top-level `run.sh` script is used to build and run containers. Use `./run.sh --help` to see a list of supported command-line options, a brief description for each, and the default value. More details are listed below.

In short, this Dockerfile and scripts will do the following:
* Build a suitable environment for compiling Firefox.
* Copy mozconfig (from `mozconfigs/`) and patches (from `patches/`) into the container.
* Run the container with X11 authentication and socket files shared.
* Copy the sources to a work directory, patch, and build.
* Run Firefox from within the container as a non-root user.

### Examples
* Build Firefox using locally stored sources at changeset FIREFOX_107_0_1_RELEASE: `./run.sh -r FIREFOX_107_0_1_RELEASE -s "${HOME}/mozilla-unified-nonbootstrapped"`


### Command-line options
#### [-c|--container]       name of Docker container

If the container does not exist then will be built.

#### [ -d|--debug]           debug mode

This option will cause the container to drop to a shell if an error occurs or when firefox exist. It should only be used when developing or debugging scripts outside of the container.

#### [-D|--downloads]       path of downloads directory shared with container

This is a directory where files will be downloaded to. The directory will be bind mounted to `/home/firefox/Downloads` within the container.

#### [-j|--jobs]            number of concurrent build jobs to run

Building Firefox is resource-intensive. Consider the following when using the `-jobs` option manually:
* CPU threads: In order to keep your computer responsive while building, keep at least one thread available for use by the OS and other apps that are running.

* Memory: When building Firefox with many threads, it can be easy to run out of memory. This may trigger your OS's out-of-memory (OOM) killer and result in build jobs being terminated, which in turn will lead to confusing build errors. Assume that each build job may take from 1-2GB of memory.

Expect the build to take at least a couple of hours, even on a fairly high-end workstation (by 2022 standards).

#### [-p|--patches]         alternative path to patches

Patches from `patches/$(uname -m)/` are applied by default. The patches/ directory is copied recursively into the Docker image. If you wish to use an alternative set of patches, copy them to a directory somewhere under `patches/` and point to it using the `-patches` option.

Patches are applied in lexicographical order. Those that do not depend on order are prefixed with `0000` followed by a hyphen before the patch name, like `git format-patch` output. Non-zero values may be used for patches that depend on the order in which they are applied.

Each sub-directory in patches/ should have a README.md file with information about the patches such as URLs from where they came.

#### [-r|--release]         Firefox release (tag, bookmark, or commit) to build

This points to the changeset to use in the Firefox sources, e.g. `mozilla-unified/`. The build system will `hg up` to this changeset.

#### [-s|--src]             path to cached Firefox sources, if desired (default: none, clone Firefox)

If this option is not set, then the build system will clone Firefox from upstream using `clone_firefox.sh`.

If this option is set, then the build system will bind mount the directory in the container, `rsync` it to the work directory, and then build it. The original source directory will not be modified.

The `--src` option should be used if you plan to build firefox often, for example if you're experimenting with patches or wish to stay up-to-date with recent tags. Cloning Firefox from upstream takes tens of minutes even at >100mbit/sec.

**Python warning**: Use `clone_firefox.sh` to clone firefox and avoid bootstrapping. Bootstrapping will set up a Python virtual environment which makes it difficult to copy the source code from one location to another. According to [https://firefox-source-docs.mozilla.org/build/buildsystem/python.html#deficiencies](https://firefox-source-docs.mozilla.org/build/buildsystem/python.html#deficiencies), *"[i]f you attempt to copy an entire tree from one machine to another or from one directory to another, chances are the venv will fall apart."*

# References
... and other places to look for ideas
* Building Firefox On Linux: [https://firefox-source-docs.mozilla.org/setup/linux_build.html](https://firefox-source-docs.mozilla.org/setup/linux_build.html)
* Talospace (ppc64le): [https://www.talospace.com](https://www.talospace.com)
* FreeBSD Firefox Makefile: https://cgit.freebsd.org/ports/tree/www/firefox/Makefile
