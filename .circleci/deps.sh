set -xeu

echo "-- ${DMD} -- "

# Deduce dmd package name/version
. .circleci/dmd.sh

# Update package cache
apt-get update

if [ "`echo $DMD_PKG | grep dmd-compiler`" ]
then
    # Remove pre-installed DMD package to avoid conflicts
    apt-get remove -y dmd-bin
fi

# Install dependencies
apt-get install -y \
    $DMD_PKG \
    libglib2.0-dev \
    libpcre3-dev \
    libxml2-dev \
    libxslt-dev \
    libebtree6-dev \
    liblzo2-dev \
    libreadline-dev \
    libbz2-dev \
    zlib1g-dev \
    libssl-dev \
    libgcrypt11-dev \
    libgpg-error-dev
