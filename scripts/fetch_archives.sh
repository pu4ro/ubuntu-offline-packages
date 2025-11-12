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

# Extract .deb packages directly to the Ubuntu version directory  
echo "Extracting .deb packages..."
docker run --rm --platform=linux/${ARCH} --entrypoint "/bin/bash" \
    ubuntu-packages:$UBUNTU_TAG \
    -c 'tar -cz /var/cache/apt/archives/*.deb' | \
    tar -xz --strip-components 4 -C archives/${UBUNTU_TAG}/

# Extract package index (keep compressed)
echo "Extracting package index..."
docker run --rm --platform=linux/${ARCH} --entrypoint "/bin/bash" \
    ubuntu-packages:$UBUNTU_TAG \
    -c 'cat /opt/Packages.gz' > archives/${UBUNTU_TAG}/Packages.gz

# Create Release file for proper APT repository
echo "Creating Release file..."
cat <<EOF > archives/${UBUNTU_TAG}/Release
Archive: ubuntu-${UBUNTU_TAG}
Version: ${UBUNTU_TAG}
Component: main
Origin: Ubuntu Offline Packages  
Label: Ubuntu Offline Packages
Architecture: ${ARCH}
Date: $(date -Ru)
Description: Ubuntu ${UBUNTU_TAG} offline packages
EOF

# Create web server setup instructions
cat <<EOF > archives/${UBUNTU_TAG}/README.md
# Ubuntu ${UBUNTU_TAG} Offline Package Repository

## Web Server Setup

1. Copy this entire directory to your web server:
   \`\`\`bash
   sudo cp -r ${UBUNTU_TAG}/ /var/www/html/
   \`\`\`

2. On client machines, add the repository:
   \`\`\`bash
   echo "deb [trusted=yes] http://YOUR_SERVER_IP/${UBUNTU_TAG} ./" | sudo tee /etc/apt/sources.list.d/ubuntu-offline-${UBUNTU_TAG}.list
   sudo apt update
   \`\`\`

3. Install packages:
   \`\`\`bash
   sudo apt install kubelet kubeadm kubectl
   \`\`\`

## Directory Structure
- \`*.deb\` - Package files
- \`Packages.gz\` - Compressed package index
- \`Release\` - Repository metadata
EOF

echo "✓ Web-ready package repository created at archives/${UBUNTU_TAG}/"
echo "✓ Copy archives/${UBUNTU_TAG}/ to /var/www/html/ on your web server"
echo ""
echo "Directory contents:"
ls -la archives/${UBUNTU_TAG}/
