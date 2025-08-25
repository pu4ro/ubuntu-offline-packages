#!/bin/bash

# Ubuntu 버전 감지
UBUNTU_VERSION=$(lsb_release -rs)

echo "Detected Ubuntu version: $UBUNTU_VERSION"

# 버전별 패키지 목록 파일 결정
if [ -f "packages/packages-${UBUNTU_VERSION}.txt" ]; then
    PACKAGE_FILE="packages/packages-${UBUNTU_VERSION}.txt"
    echo "Using specific package list: $PACKAGE_FILE"
else
    # 기본 패키지 목록 사용
    PACKAGE_FILE="packages/packages-22.04.txt"
    echo "Using default package list: $PACKAGE_FILE (no specific list found for $UBUNTU_VERSION)"
fi

# 패키지 목록 읽어서 설치
if [ -f "$PACKAGE_FILE" ]; then
    echo "Installing packages from $PACKAGE_FILE..."
    
    # 패키지 목록을 한 줄로 만들어서 설치
    PACKAGES=$(cat "$PACKAGE_FILE" | grep -v '^#' | grep -v '^$' | tr '\n' ' ')
    
    echo "Packages to install: $PACKAGES"
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES
else
    echo "Error: Package file $PACKAGE_FILE not found!"
    exit 1
fi