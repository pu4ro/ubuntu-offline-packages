.PHONY: build-22.04 build-24.04 build-20.04 fetch-22.04 fetch-24.04 fetch-20.04 clean clean-archives help

REGISTRY := ubuntu-packages
KUBE_VER ?= 1.27

build-22.04:
	@echo "Building Ubuntu 22.04 packages (Kubernetes $(KUBE_VER))..."
	docker build --build-arg UBUNTU_VERSION=22.04.5-lts --build-arg KUBE_VER=$(KUBE_VER) -t $(REGISTRY):22.04 .
	@echo "✓ Successfully built $(REGISTRY):22.04"

build-24.04:
	@echo "Building Ubuntu 24.04 packages (Kubernetes $(KUBE_VER))..."
	docker build --build-arg UBUNTU_VERSION=24.04.3-lts --build-arg KUBE_VER=$(KUBE_VER) -t $(REGISTRY):24.04 .
	@echo "✓ Successfully built $(REGISTRY):24.04"

build-20.04:
	@echo "Building Ubuntu 20.04 packages (Kubernetes $(KUBE_VER))..."
	docker build --build-arg UBUNTU_VERSION=20.04.6-lts --build-arg KUBE_VER=$(KUBE_VER) -t $(REGISTRY):20.04 .
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
	@echo "  KUBE_VER=x.xx  - Kubernetes version (default: 1.27)"
	@echo ""
	@echo "Example:"
	@echo "  make build-24.04 KUBE_VER=1.28"