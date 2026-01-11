.PHONY: build-22.04 build-24.04 build-20.04 fetch-22.04 fetch-24.04 fetch-20.04 clean clean-archives help

REGISTRY := ubuntu-packages
KUBE_VER ?= 1.34
KUBE_PATCH_VER ?=
CONTAINERD_VER ?= 2.0.0
NO_CACHE ?=

# Build args for versions
BUILD_ARGS := --build-arg KUBE_VER=$(KUBE_VER) --build-arg CONTAINERD_VER=$(CONTAINERD_VER)
ifneq ($(KUBE_PATCH_VER),)
  BUILD_ARGS += --build-arg KUBE_PATCH_VER=$(KUBE_PATCH_VER)
  KUBE_VERSION_DISPLAY := $(KUBE_PATCH_VER)
else
  KUBE_VERSION_DISPLAY := $(KUBE_VER).x (latest)
endif

# Add --no-cache if NO_CACHE=1
ifeq ($(NO_CACHE),1)
  BUILD_ARGS += --no-cache
endif

build-22.04:
	@echo "Building Ubuntu 22.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	docker build --build-arg UBUNTU_VERSION=22.04.5-lts $(BUILD_ARGS) -t $(REGISTRY):22.04 .
	@echo "✓ Successfully built $(REGISTRY):22.04"

build-24.04:
	@echo "Building Ubuntu 24.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	docker build --build-arg UBUNTU_VERSION=24.04.3-lts $(BUILD_ARGS) -t $(REGISTRY):24.04 .
	@echo "✓ Successfully built $(REGISTRY):24.04"

build-20.04:
	@echo "Building Ubuntu 20.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	docker build --build-arg UBUNTU_VERSION=20.04.6-lts $(BUILD_ARGS) -t $(REGISTRY):20.04 .
	@echo "✓ Successfully built $(REGISTRY):20.04"

fetch-22.04: build-22.04
	@echo "Fetching archives for Ubuntu 22.04..."
	UBUNTU_VERSION=22.04.5-lts bash scripts/fetch_archives.sh
	@echo "✓ Archives fetched for Ubuntu 22.04"

fetch-24.04: build-24.04
	@echo "Fetching archives for Ubuntu 24.04..."
	UBUNTU_VERSION=24.04.3-lts bash scripts/fetch_archives.sh
	@echo "✓ Archives fetched for Ubuntu 24.04"

fetch-20.04: build-20.04
	@echo "Fetching archives for Ubuntu 20.04..."
	UBUNTU_VERSION=20.04.6-lts bash scripts/fetch_archives.sh
	@echo "✓ Archives fetched for Ubuntu 20.04"

clean:
	@echo "Cleaning up Docker images..."
	docker rmi $(REGISTRY):22.04 $(REGISTRY):24.04 $(REGISTRY):20.04 || true
	@echo "✓ Cleanup completed"

clean-archives:
	@echo "Cleaning up archives..."
	rm -rf archives/
	@echo "✓ Archives cleanup completed"

help:
	@echo "Available targets:"
	@echo "  build-20.04    - Build packages for Ubuntu 20.04"
	@echo "  build-22.04    - Build packages for Ubuntu 22.04"
	@echo "  build-24.04    - Build packages for Ubuntu 24.04"
	@echo "  fetch-20.04    - Build and fetch archives for Ubuntu 20.04"
	@echo "  fetch-22.04    - Build and fetch archives for Ubuntu 22.04"
	@echo "  fetch-24.04    - Build and fetch archives for Ubuntu 24.04"
	@echo "  clean          - Remove all built Docker images"
	@echo "  clean-archives - Remove all extracted archives"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  KUBE_VER=x.xx        - Kubernetes minor version: 1.32, 1.33, 1.34, 1.35 (default: 1.34)"
	@echo "  KUBE_PATCH_VER=x.x.x - Specific K8s patch version (optional, e.g., 1.34.3)"
	@echo "  CONTAINERD_VER=x.x.x - containerd version: 2.0.0, 2.0.1, 2.1.0, etc. (default: 2.0.0)"
	@echo "  NO_CACHE=1           - Build without Docker cache (recommended for version changes)"
	@echo ""
	@echo "Compatibility (containerd <-> Kubernetes):"
	@echo "  K8s 1.34: containerd 2.1.3+, 2.0.6+, 1.7.28+"
	@echo "  K8s 1.35: containerd 2.2.0+, 2.1.5+, 1.7.28+"
	@echo ""
	@echo "Examples:"
	@echo "  make build-24.04                                        # K8s 1.34.x, containerd 2.0.0"
	@echo "  make build-24.04 KUBE_VER=1.35 CONTAINERD_VER=2.0.0     # K8s 1.35.x, containerd 2.0.0"
	@echo "  make build-24.04 KUBE_PATCH_VER=1.34.3 NO_CACHE=1       # Specific version, no cache"