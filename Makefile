.PHONY: build-22.04 build-24.04 build-20.04 fetch-22.04 fetch-24.04 fetch-20.04 clean clean-archives setup-buildx clean-buildx help

REGISTRY := ubuntu-packages
KUBE_VER ?= 1.34
KUBE_PATCH_VER ?=
CONTAINERD_VER ?= 2.2.0
NO_CACHE ?=
BUILDX_STORAGE ?=
BUILDX_NAME ?= ubuntu-pkg-builder

# Docker buildx command
DOCKER_BUILDX := docker buildx build

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

# Buildx driver options
BUILDX_DRIVER_OPTS :=
ifneq ($(BUILDX_STORAGE),)
  BUILDX_DRIVER_OPTS := --driver-opt "image=moby/buildkit:latest,network=host" --driver-opt "volume-mounts=$(BUILDX_STORAGE):/var/lib/buildkit"
endif

# Setup buildx builder
setup-buildx:
	@echo "Setting up Docker Buildx..."
	@docker buildx rm $(BUILDX_NAME) 2>/dev/null || true
	@docker buildx create --name $(BUILDX_NAME) --driver docker-container $(BUILDX_DRIVER_OPTS) --use
	@docker buildx inspect --bootstrap
	@echo "✓ Buildx ready (builder: $(BUILDX_NAME))"
ifneq ($(BUILDX_STORAGE),)
	@echo "✓ Storage: $(BUILDX_STORAGE)"
endif

# Build targets (create docker image)
build-22.04:
	@echo "Building Ubuntu 22.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	$(DOCKER_BUILDX) --load --build-arg UBUNTU_VERSION=22.04.5-lts $(BUILD_ARGS) -t $(REGISTRY):22.04 .
	@echo "✓ Successfully built $(REGISTRY):22.04"

build-24.04:
	@echo "Building Ubuntu 24.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	$(DOCKER_BUILDX) --load --build-arg UBUNTU_VERSION=24.04.3-lts $(BUILD_ARGS) -t $(REGISTRY):24.04 .
	@echo "✓ Successfully built $(REGISTRY):24.04"

build-20.04:
	@echo "Building Ubuntu 20.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	$(DOCKER_BUILDX) --load --build-arg UBUNTU_VERSION=20.04.6-lts $(BUILD_ARGS) -t $(REGISTRY):20.04 .
	@echo "✓ Successfully built $(REGISTRY):20.04"

# Fetch targets (extract packages using buildx --output)
fetch-22.04:
	@echo "Fetching Ubuntu 22.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	@rm -rf archives/22.04 && mkdir -p archives/22.04
	$(DOCKER_BUILDX) --target export --output type=local,dest=archives/22.04 \
		--build-arg UBUNTU_VERSION=22.04.5-lts $(BUILD_ARGS) .
	@mv archives/22.04/packages/* archives/22.04/ && rm -rf archives/22.04/packages
	@bash scripts/create-release.sh 22.04
	@echo "✓ Packages extracted to archives/22.04/"

fetch-24.04:
	@echo "Fetching Ubuntu 24.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	@rm -rf archives/24.04 && mkdir -p archives/24.04
	$(DOCKER_BUILDX) --target export --output type=local,dest=archives/24.04 \
		--build-arg UBUNTU_VERSION=24.04.3-lts $(BUILD_ARGS) .
	@mv archives/24.04/packages/* archives/24.04/ && rm -rf archives/24.04/packages
	@bash scripts/create-release.sh 24.04
	@echo "✓ Packages extracted to archives/24.04/"

fetch-20.04:
	@echo "Fetching Ubuntu 20.04 packages (K8s: $(KUBE_VERSION_DISPLAY), containerd: $(CONTAINERD_VER))..."
	@rm -rf archives/20.04 && mkdir -p archives/20.04
	$(DOCKER_BUILDX) --target export --output type=local,dest=archives/20.04 \
		--build-arg UBUNTU_VERSION=20.04.6-lts $(BUILD_ARGS) .
	@mv archives/20.04/packages/* archives/20.04/ && rm -rf archives/20.04/packages
	@bash scripts/create-release.sh 20.04
	@echo "✓ Packages extracted to archives/20.04/"

clean:
	@echo "Cleaning up Docker images..."
	@docker rmi $(REGISTRY):22.04 $(REGISTRY):24.04 $(REGISTRY):20.04 2>/dev/null || true
	@echo "✓ Cleanup completed"

clean-archives:
	@echo "Cleaning up archives..."
	@rm -rf archives/
	@echo "✓ Archives cleanup completed"

clean-buildx:
	@echo "Cleaning up Buildx cache..."
	@docker buildx prune -f
	@echo "✓ Buildx cache cleaned"

help:
	@echo "Available targets:"
	@echo "  setup-buildx   - Setup Docker Buildx builder (run once)"
	@echo "  build-{ver}    - Build Docker image (20.04, 22.04, 24.04)"
	@echo "  fetch-{ver}    - Build and extract packages directly (recommended)"
	@echo "  clean          - Remove all built Docker images"
	@echo "  clean-archives - Remove all extracted archives"
	@echo "  clean-buildx   - Clean Buildx cache"
	@echo ""
	@echo "Options:"
	@echo "  KUBE_VER=x.xx        - Kubernetes minor version (default: 1.34)"
	@echo "  KUBE_PATCH_VER=x.x.x - Specific K8s patch version"
	@echo "  CONTAINERD_VER=x.x.x - containerd version (default: 2.2.0)"
	@echo "  NO_CACHE=1           - Build without cache"
	@echo "  BUILDX_STORAGE=/path - Custom buildx storage directory"
	@echo "  BUILDX_NAME=name     - Custom buildx builder name (default: ubuntu-pkg-builder)"
	@echo ""
	@echo "Quick Start:"
	@echo "  make setup-buildx"
	@echo "  make fetch-24.04"
	@echo ""
	@echo "With custom storage:"
	@echo "  make setup-buildx BUILDX_STORAGE=/mnt/build-storage"
	@echo "  make fetch-24.04"
	@echo ""
	@echo "Examples:"
	@echo "  make fetch-24.04 KUBE_VER=1.35 CONTAINERD_VER=2.2.0"
	@echo "  make fetch-24.04 KUBE_PATCH_VER=1.34.3 NO_CACHE=1"
