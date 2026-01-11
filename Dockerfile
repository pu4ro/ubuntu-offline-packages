# syntax=docker/dockerfile:1.4
ARG UBUNTU_VERSION=22.04.5-lts

#######################################
# Stage 1: Go Builder
#######################################
FROM golang:1.24 AS go-builder

ENV NERDCTL_VER=2.0.3
ENV BUILDKIT_VER=0.19.0
ENV RUNC_VER=1.2.4
ARG CONTAINERD_VER=2.2.0

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    gcc \
    libseccomp-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Clone all repositories in parallel using a single RUN
RUN git clone --depth 1 --branch v${NERDCTL_VER} https://github.com/containerd/nerdctl.git /build/nerdctl && \
    git clone --depth 1 --branch v${BUILDKIT_VER} https://github.com/moby/buildkit.git /build/buildkit && \
    git clone --depth 1 --branch v${RUNC_VER} https://github.com/opencontainers/runc.git /build/runc && \
    git clone --depth 1 --branch v${CONTAINERD_VER} https://github.com/containerd/containerd.git /build/containerd

# Build all Go binaries with cache mount
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    mkdir -p /out && \
    # nerdctl
    cd /build/nerdctl && CGO_ENABLED=1 go build -o /out/nerdctl ./cmd/nerdctl && \
    # buildkit (use go build directly, not make which requires docker)
    cd /build/buildkit && \
    CGO_ENABLED=0 go build -o /out/buildkitd ./cmd/buildkitd && \
    CGO_ENABLED=0 go build -o /out/buildctl ./cmd/buildctl && \
    # runc
    cd /build/runc && make -j$(nproc) && cp runc /out/ && \
    # containerd
    cd /build/containerd && make -j$(nproc) && cp bin/* /out/

#######################################
# Stage 2: Package Builder
#######################################
FROM cr.makina.rocks/external-hub/ubuntu:${UBUNTU_VERSION} AS package-builder

ARG KUBE_VER=1.34
ARG KUBE_PATCH_VER=
ARG CONTAINERD_VER=2.2.0
ENV HELMFILE_VER=0.169.1
ENV HELM_VER=3.16.2
ENV NERDCTL_VER=2.0.3
ENV BUILDKIT_VER=0.19.0
ENV RUNC_VER=1.2.4

WORKDIR /opt

# Copy built binaries from go-builder stage
COPY --from=go-builder /out/ /opt/bin/

# Install base dependencies and setup repositories in single layer
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        gpg \
        wget \
        apt-transport-https \
        software-properties-common \
        dpkg-dev \
        ca-certificates && \
    # Add Kubernetes repository
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VER}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VER}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list && \
    # Add Ansible PPA
    add-apt-repository --yes ppa:ansible/ansible && \
    apt-get update

# Copy and install packages
COPY packages/ ./packages/
COPY scripts/install-packages.sh ./
RUN bash install-packages.sh && \
    # Install Kubernetes packages
    if [ -n "${KUBE_PATCH_VER}" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            kubelet=${KUBE_PATCH_VER}-1.1 \
            kubeadm=${KUBE_PATCH_VER}-1.1 \
            kubectl=${KUBE_PATCH_VER}-1.1; \
    else \
        DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl; \
    fi

# Build all deb packages in single layer
COPY control-files/ ./control-files/
RUN set -e && \
    ARCH=$(dpkg --print-architecture) && \
    #
    # === Helm ===
    mkdir -p helm_deb/usr/local/bin helm_deb/DEBIAN && \
    curl -sL https://get.helm.sh/helm-v${HELM_VER}-linux-${ARCH}.tar.gz | tar -xz && \
    cp linux-${ARCH}/helm helm_deb/usr/local/bin/ && \
    cp control-files/control-helm helm_deb/DEBIAN/control && \
    dpkg-deb --build helm_deb helm_${HELM_VER}_${ARCH}.deb && \
    cp helm_${HELM_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf helm_deb linux-${ARCH} && \
    #
    # === Helmfile ===
    mkdir -p helmfile_deb/usr/bin helmfile_deb/DEBIAN helmfile_deb/root && \
    curl -sL https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VER}/helmfile_${HELMFILE_VER}_linux_${ARCH}.tar.gz | tar -xz && \
    ./helmfile init --force && \
    cp helmfile helmfile_deb/usr/bin/ && \
    cp -a /root/.local helmfile_deb/root/ && \
    cp control-files/control helmfile_deb/DEBIAN/control && \
    dpkg-deb --build helmfile_deb helmfile_${HELMFILE_VER}_${ARCH}.deb && \
    cp helmfile_${HELMFILE_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf helmfile_deb helmfile /root/.local && \
    #
    # === Nerdctl ===
    mkdir -p nerdctl_deb/usr/bin nerdctl_deb/DEBIAN && \
    cp /opt/bin/nerdctl nerdctl_deb/usr/bin/ && \
    cp control-files/control-nerdctl nerdctl_deb/DEBIAN/control && \
    dpkg-deb --build nerdctl_deb nerdctl_${NERDCTL_VER}_${ARCH}.deb && \
    cp nerdctl_${NERDCTL_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf nerdctl_deb && \
    #
    # === Runc ===
    mkdir -p runc_deb/usr/local/bin runc_deb/DEBIAN && \
    cp /opt/bin/runc runc_deb/usr/local/bin/ && \
    echo "Package: runc\nVersion: ${RUNC_VER}\nArchitecture: ${ARCH}\nMaintainer: DevOps <devops@example.com>\nDescription: CLI tool for spawning and running containers" > runc_deb/DEBIAN/control && \
    dpkg-deb --build runc_deb runc_${RUNC_VER}_${ARCH}.deb && \
    cp runc_${RUNC_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf runc_deb && \
    #
    # === Containerd ===
    mkdir -p containerd_deb/usr/local/bin containerd_deb/DEBIAN containerd_deb/lib/systemd/system containerd_deb/etc/containerd && \
    cp /opt/bin/containerd /opt/bin/containerd-shim* /opt/bin/ctr containerd_deb/usr/local/bin/ && \
    curl -sL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o containerd_deb/lib/systemd/system/containerd.service && \
    echo '#!/bin/bash\nset -e\nif [ ! -f /etc/containerd/config.toml ]; then\n  /usr/local/bin/containerd config default > /etc/containerd/config.toml\n  sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml\nfi\nsystemctl daemon-reload\nsystemctl enable containerd' > containerd_deb/DEBIAN/postinst && \
    chmod +x containerd_deb/DEBIAN/postinst && \
    echo "Package: containerd\nVersion: ${CONTAINERD_VER}\nArchitecture: ${ARCH}\nDepends: runc\nMaintainer: DevOps <devops@example.com>\nDescription: An open and reliable container runtime" > containerd_deb/DEBIAN/control && \
    dpkg-deb --build containerd_deb containerd_${CONTAINERD_VER}_${ARCH}.deb && \
    cp containerd_${CONTAINERD_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf containerd_deb && \
    #
    # === BuildKit ===
    mkdir -p buildkit_deb/usr/bin buildkit_deb/DEBIAN buildkit_deb/lib/systemd/system && \
    cp /opt/bin/buildkitd /opt/bin/buildctl buildkit_deb/usr/bin/ && \
    curl -sL https://raw.githubusercontent.com/moby/buildkit/master/examples/systemd/system/buildkit.service -o buildkit_deb/lib/systemd/system/buildkit.service && \
    curl -sL https://raw.githubusercontent.com/moby/buildkit/master/examples/systemd/system/buildkit.socket -o buildkit_deb/lib/systemd/system/buildkit.socket && \
    echo '#!/bin/bash\nset -e\nmkdir -p /etc/buildkit\ncat <<EOF > /etc/buildkit/buildkitd.toml\n[worker.oci]\n  enabled = false\n[worker.containerd]\n  enabled = true\n  namespace = "k8s.io"\nEOF\ncp /usr/bin/buildkitd /usr/local/bin/buildkitd\ncp /usr/bin/buildctl /usr/local/bin/buildctl\nsystemctl daemon-reload\nsystemctl enable --now buildkit.service' > buildkit_deb/DEBIAN/postinst && \
    chmod +x buildkit_deb/DEBIAN/postinst && \
    cp control-files/control-buildkit buildkit_deb/DEBIAN/control && \
    dpkg-deb --build buildkit_deb buildkit_${BUILDKIT_VER}_${ARCH}.deb && \
    cp buildkit_${BUILDKIT_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf buildkit_deb && \
    #
    # === K9s (download latest) ===
    mkdir -p k9s_deb/usr/bin k9s_deb/DEBIAN && \
    K9S_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//') && \
    curl -sL https://github.com/derailed/k9s/releases/download/v${K9S_VER}/k9s_Linux_${ARCH}.tar.gz | tar -xz -C k9s_deb/usr/bin k9s && \
    echo "Package: k9s\nVersion: ${K9S_VER}\nArchitecture: ${ARCH}\nMaintainer: DevOps <devops@example.com>\nDescription: K9s Kubernetes CLI tool" > k9s_deb/DEBIAN/control && \
    dpkg-deb --build k9s_deb k9s_${K9S_VER}_${ARCH}.deb && \
    cp k9s_${K9S_VER}_${ARCH}.deb /var/cache/apt/archives/ && \
    rm -rf k9s_deb && \
    #
    # Cleanup built binaries
    rm -rf /opt/bin

# Generate package index
WORKDIR /var/cache/apt/archives
RUN dpkg-scanpackages . /dev/null | gzip -9c > /opt/Packages.gz

# Generate install script
WORKDIR /var/cache/apt
COPY scripts/create-apt-get-install-with-version.sh .
RUN bash create-apt-get-install-with-version.sh > /opt/apt-get-install-with-version.sh

#######################################
# Stage 3: Export (for buildx --output)
#######################################
FROM scratch AS export
COPY --from=package-builder /var/cache/apt/archives/*.deb /packages/
COPY --from=package-builder /opt/Packages.gz /packages/
COPY --from=package-builder /opt/apt-get-install-with-version.sh /packages/
