#!/bin/sh
set -xe

# Travis likes to fetch submodules recursively, but the build system assumes
# shalow submodules fetching, so we need to remove all the recursive submodules
# before proceeding
git submodule foreach --recursive git submodule deinit --force --all

# Defaults (in case they are not set by the CI)
F=${F:-production}
DC=${DC:-dmd1}
DIST=${DIST:-xenial}

DVER=1
if test "$DC" != dmd1; then
	DVER=2
fi

export DC DVER

if test "$DC" != dmd1; then
	make -r d2conv
fi

make -r all
make -r test
