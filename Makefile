.PHONY: build-22.04 build-24.04 build-20.04 fetch-22.04 fetch-24.04 fetch-20.04 clean clean-archives help

REGISTRY := ubuntu-packages

build-22.04:
	@echo "Building Ubuntu 22.04 packages..."
	docker build --build-arg UBUNTU_VERSION=22.04.5-lts -t $(REGISTRY):22.04 .
	@echo "✓ Successfully built $(REGISTRY):22.04"

build-24.04:
	@echo "Building Ubuntu 24.04 packages..."
	docker build --build-arg UBUNTU_VERSION=24.04.3-lts -t $(REGISTRY):24.04 .
	@echo "✓ Successfully built $(REGISTRY):24.04"

build-20.04:
	@echo "Building Ubuntu 20.04 packages..."
	docker build --build-arg UBUNTU_VERSION=20.04.6-lts -t $(REGISTRY):20.04 .
	@echo "✓ Successfully built $(REGISTRY):20.04"

fetch-22.04: build-22.04
	@echo "Fetching archives for Ubuntu 22.04..."
	UBUNTU_VERSION=22.04.5-lts bash fetch_archives.sh
	@echo "✓ Archives fetched for Ubuntu 22.04"

fetch-24.04: build-24.04
	@echo "Fetching archives for Ubuntu 24.04..."
	UBUNTU_VERSION=24.04.3-lts bash fetch_archives.sh
	@echo "✓ Archives fetched for Ubuntu 24.04"

fetch-20.04: build-20.04
	@echo "Fetching archives for Ubuntu 20.04..."
	UBUNTU_VERSION=20.04.6-lts bash fetch_archives.sh
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