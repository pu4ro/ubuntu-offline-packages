#!/bin/bash

UBUNTU_VERSION=$(lsb_release -rs)

echo "Installing packages for Ubuntu $UBUNTU_VERSION"

# 공통 패키지
COMMON_PACKAGES="kubelet kubeadm kubectl nfs-common bash-completion dnsmasq jq openssh-server net-tools ca-certificates containerd chrony apache2 vim-tiny zstd helm dialog build-essential"

# 버전별 추가 패키지
case "$UBUNTU_VERSION" in
    "20.04")
        ADDITIONAL_PACKAGES="python3-pip"
        ;;
    "22.04")
        ADDITIONAL_PACKAGES="python3-pip snapd"
        ;;
    "24.04")
        ADDITIONAL_PACKAGES="python3-pip snapd systemd-container"
        ;;
    *)
        echo "Unknown Ubuntu version: $UBUNTU_VERSION, using default packages"
        ADDITIONAL_PACKAGES="python3-pip"
        ;;
esac

ALL_PACKAGES="$COMMON_PACKAGES $ADDITIONAL_PACKAGES"

echo "Installing: $ALL_PACKAGES"
DEBIAN_FRONTEND=noninteractive apt-get install -y $ALL_PACKAGES