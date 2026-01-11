#!/bin/bash
set -e

UBUNTU_TAG=${1:-24.04}
ARCHIVE_DIR="archives/${UBUNTU_TAG}"
ARCH=${ARCH:-amd64}

# Create Release file
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
DEB_COUNT=$(find "${ARCHIVE_DIR}" -name "*.deb" 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "${ARCHIVE_DIR}" 2>/dev/null | cut -f1)
echo "  Packages: ${DEB_COUNT} deb files"
echo "  Total size: ${TOTAL_SIZE}"
