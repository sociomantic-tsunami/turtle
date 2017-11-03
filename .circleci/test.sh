set -xeu

# Binary name deduced based on supplied DMD version
case "$DMD" in
    dmd*   ) DC="$DMD"
            DVER=2
            if test "$DMD" = dmd1
            then
                DVER=1
            fi
            ;;
    1.*    ) DC=dmd1 DVER=1 ;;
    2.*.s* ) DC=dmd-transitional DVER=2 ;;
    2.*    ) DC=dmd DVER=2 ;;
    *      ) echo "Unknown \$DMD ($DMD)" >&2; false ;;
esac

if test "$DVER" -eq "2"
then
    make d2conv
fi

set -v
make test F=$F DVER=$DVER DC=$DC
