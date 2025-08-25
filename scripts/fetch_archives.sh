#!/bin/bash

# Default values
ARCH=${ARCH:-amd64}
UBUNTU_VERSION=${UBUNTU_VERSION:-22.04.5-lts}
HELMFILE_VER=${HELMFILE_VER:-0.169.1}

# Extract version tag from Ubuntu version
UBUNTU_TAG=$(echo "$UBUNTU_VERSION" | cut -d'.' -f1,2)

echo "Fetching archives for:"
echo "  Ubuntu: $UBUNTU_VERSION (tag: $UBUNTU_TAG)"
echo "  Architecture: $ARCH"
echo "  Helmfile: $HELMFILE_VER"

# Create control file
cat <<EOF >control
Package: helmfile
Version: ${HELMFILE_VER}
Architecture: ${ARCH}
Maintainer: Sangwoo Shim <sangwoo@makinarocks.ai>
Description: Helmfile package
Depends: git, helm
EOF

# Build image with specified Ubuntu version
echo "Building Docker image for Ubuntu $UBUNTU_VERSION..."
docker build --build-arg UBUNTU_VERSION="$UBUNTU_VERSION" \
             -t ubuntu-packages:$UBUNTU_TAG \
             --platform=linux/${ARCH} .

# Create archives directory
mkdir -p archives/${UBUNTU_TAG}

# Extract archives
echo "Extracting .deb packages..."
docker run --rm --platform=linux/${ARCH} --entrypoint "/bin/bash" \
    ubuntu-packages:$UBUNTU_TAG \
    -c 'tar -cz /var/cache/apt/archives/*.deb' | \
    tar -xz --strip-components 3 -C archives/${UBUNTU_TAG}/

# Extract package index
echo "Extracting package index..."
docker run --rm --platform=linux/${ARCH} --entrypoint "/bin/bash" \
    ubuntu-packages:$UBUNTU_TAG \
    -c 'cat /opt/Packages.gz' > archives/${UBUNTU_TAG}/Packages.gz

# Extract install script
echo "Extracting install script..."
docker run --rm --platform=linux/${ARCH} --entrypoint "/bin/bash" \
    ubuntu-packages:$UBUNTU_TAG \
    -c 'cat /opt/apt-get-install-with-version.sh' > archives/${UBUNTU_TAG}/apt-get-install-with-version.sh

echo "✓ Archives extracted to archives/${UBUNTU_TAG}/"
echo "Contents:"
ls -la archives/${UBUNTU_TAG}/
