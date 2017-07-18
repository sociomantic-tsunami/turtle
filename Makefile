# turtle is a source library, so default goal
# simply runs library tests
.DEFAULT_GOAL := test

# Include the top-level makefile
include submodules/makd/Makd.mak
