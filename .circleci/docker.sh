set -eu

# Package name deduced based on supplied DMD version
case "$DMD" in
    dmd*   ) PKG= ;;
    1.*    ) PKG="dmd1=$DMD-$DIST" ;;
    2.*.s* ) PKG="dmd-transitional=$DMD-$DIST" ;;
    2.*    ) PKG="dmd-bin=$DMD libphobos2-dev=$DMD" ;;
    *      ) echo "Unknown \$DMD ($DMD)" >&2; exit 1 ;;
esac

# Generate the Dockerfile including the DMD_PKG argument and install the
# relevant DMD
./submodules/beaver/bin/docker/gen-dockerfile \
        -i beaver.Dockerfile \
        -I 'ARG DMD_PKG' -I 'ENV DMD_PKG=$DMD_PKG' \
        -I 'RUN apt-get update && apt-get -y install --force-yes $DMD_PKG' \
        -o beaver.Dockerfile.generated

# Build the docker image from the generated Dockerfile passing DMD_PKG
./submodules/beaver/bin/docker/build --build-arg "DMD_PKG=$PKG" \
    --cache-from=beaver -f beaver.Dockerfile.generated "$@" .
