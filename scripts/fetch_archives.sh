#!/bin/bash
set -e

# Default values
ARCH=${ARCH:-amd64}
UBUNTU_VERSION=${UBUNTU_VERSION:-22.04.5-lts}

# Extract version tag from Ubuntu version
UBUNTU_TAG=$(echo "$UBUNTU_VERSION" | cut -d'.' -f1,2)
IMAGE_NAME="ubuntu-packages:${UBUNTU_TAG}"
CONTAINER_NAME="ubuntu-packages-extract-$$"

echo "============================================"
echo "Fetching archives for Ubuntu ${UBUNTU_TAG}"
echo "  Architecture: ${ARCH}"
echo "============================================"

# Check if image exists
if ! docker image inspect "${IMAGE_NAME}" &>/dev/null; then
    echo "Error: Image ${IMAGE_NAME} not found."
    echo "Run 'make build-${UBUNTU_TAG}' first."
    exit 1
fi

# Create archives directory
ARCHIVE_DIR="archives/${UBUNTU_TAG}"
rm -rf "${ARCHIVE_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# Create temporary container and extract all files at once
echo "Extracting packages..."
docker create --name "${CONTAINER_NAME}" --platform=linux/${ARCH} "${IMAGE_NAME}" /bin/true >/dev/null

# Copy all deb files and metadata in parallel
docker cp "${CONTAINER_NAME}:/var/cache/apt/archives/." "${ARCHIVE_DIR}/" &
PID1=$!
docker cp "${CONTAINER_NAME}:/opt/Packages.gz" "${ARCHIVE_DIR}/" &
PID2=$!
docker cp "${CONTAINER_NAME}:/opt/apt-get-install-with-version.sh" "${ARCHIVE_DIR}/" 2>/dev/null &
PID3=$!

# Wait for all copies to complete
wait $PID1 $PID2 $PID3 2>/dev/null || true

# Cleanup container
docker rm "${CONTAINER_NAME}" >/dev/null

# Remove non-deb files from archives (lock, partial dir, etc)
find "${ARCHIVE_DIR}" -type f ! -name "*.deb" ! -name "*.gz" ! -name "*.sh" ! -name "Release" ! -name "README.md" -delete 2>/dev/null || true
find "${ARCHIVE_DIR}" -type d -empty -delete 2>/dev/null || true

# Create Release file for APT repository
cat <<EOF > "${ARCHIVE_DIR}/Release"
Archive: ubuntu-${UBUNTU_TAG}
Version: ${UBUNTU_TAG}
Component: main
Origin: Ubuntu Offline Packages
Label: Ubuntu Offline Packages
Architecture: ${ARCH}
Date: $(date -Ru)
Description: Ubuntu ${UBUNTU_TAG} offline packages
EOF

# Create README
cat <<EOF > "${ARCHIVE_DIR}/README.md"
# Ubuntu ${UBUNTU_TAG} Offline Package Repository

## Quick Setup

1. Copy to web server:
   \`\`\`bash
   sudo cp -r ${UBUNTU_TAG}/ /var/www/html/
   \`\`\`

2. On client machines:
   \`\`\`bash
   echo "deb [trusted=yes] http://YOUR_SERVER/${UBUNTU_TAG} ./" | sudo tee /etc/apt/sources.list.d/offline.list
   sudo apt update
   sudo apt install kubelet kubeadm kubectl containerd runc
   \`\`\`
EOF

# Summary
echo ""
echo "============================================"
echo "Fetch completed: ${ARCHIVE_DIR}/"
echo "============================================"
DEB_COUNT=$(find "${ARCHIVE_DIR}" -name "*.deb" | wc -l)
TOTAL_SIZE=$(du -sh "${ARCHIVE_DIR}" | cut -f1)
echo "  Packages: ${DEB_COUNT} deb files"
echo "  Total size: ${TOTAL_SIZE}"
