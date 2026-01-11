ARG UBUNTU_VERSION=22.04.5-lts
FROM cr.makina.rocks/external-hub/ubuntu:${UBUNTU_VERSION}

ENV HELMFILE_VER=0.169.1
ENV KUBE_VER=1.27
ENV NERDCTL_VER=1.6.0
ENV BUILDKIT_VER=0.12.2
ENV GO_VERSION=1.20.5
ENV ARCH=amd64

WORKDIR /opt

RUN mkdir -p /opt/helmfile_deb
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    curl \
    gpg \
    build-essential \
    cmake \
    libseccomp-dev \
    wget \
    apt-transport-https \
    python3-pip \
    golang \
    gcc \
    unzip \
    make

# Install Go
RUN wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Add Kubernetes repository
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VER}/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list

# Add Ansible PPA repository
RUN apt-get install -y software-properties-common && \
    add-apt-repository --yes ppa:ansible/ansible

COPY packages/ ./packages/
COPY scripts/install-packages.sh ./
RUN apt-get update && bash install-packages.sh

# Build and package helm
ENV HELM_VER=3.16.2
RUN mkdir -p helm_deb/usr/local/bin && mkdir -p helm_deb/DEBIAN
COPY control-files/control-helm helm_deb/DEBIAN/control
RUN ARCH=$(dpkg --print-architecture) && \
    curl -L https://get.helm.sh/helm-v${HELM_VER}-linux-${ARCH}.tar.gz | tar -xz && \
    cp linux-${ARCH}/helm helm_deb/usr/local/bin/ && \
    rm -rf linux-${ARCH} && \
    mv helm_deb helm_${HELM_VER}_linux_${ARCH} && \
    dpkg-deb --build helm_${HELM_VER}_linux_${ARCH}
RUN ARCH=$(dpkg --print-architecture) && \
    apt-get install -y ./helm_${HELM_VER}_linux_${ARCH}.deb && \
    cp -a ./helm_${HELM_VER}_linux_${ARCH}.deb /var/cache/apt/archives

# Prepare helmfile deb package
RUN mkdir -p helmfile_deb/usr/bin && mkdir -p helmfile_deb/DEBIAN && mkdir -p helmfile_deb/root
COPY control-files/control helmfile_deb/DEBIAN/control
RUN ARCH=$(dpkg --print-architecture) && \
    curl -L https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VER}/helmfile_${HELMFILE_VER}_linux_${ARCH}.tar.gz | tar -xz && \
    ./helmfile init --force && \
    cp -a helmfile helmfile_deb/usr/bin && \
    cp -a /root/.local helmfile_deb/root/ && \
    mv helmfile_deb helmfile_${HELMFILE_VER}_linux_${ARCH} && \
    dpkg-deb --build helmfile_${HELMFILE_VER}_linux_${ARCH}
RUN ARCH=$(dpkg --print-architecture) && rm -rf /root/.local && apt-get install -y ./helmfile_${HELMFILE_VER}_linux_${ARCH}.deb && \
    cp -a ./helmfile_${HELMFILE_VER}_linux_${ARCH}.deb /var/cache/apt/archives

# Build and package nerdctl
RUN git clone --branch v${NERDCTL_VER} https://github.com/containerd/nerdctl.git /opt/nerdctl-source
WORKDIR /opt/nerdctl-source
RUN mkdir -p nerdctl_deb/usr/bin && \
    CGO_ENABLED=1 go build -o nerdctl ./cmd/nerdctl && \
    cp nerdctl nerdctl_deb/usr/bin/ && mkdir -p nerdctl_deb/DEBIAN
COPY control-files/control-nerdctl nerdctl_deb/DEBIAN/control
RUN ARCH=$(dpkg --print-architecture) && \
    mv nerdctl_deb nerdctl_${NERDCTL_VER}_linux_${ARCH} && \
    dpkg-deb --build nerdctl_${NERDCTL_VER}_linux_${ARCH}
RUN cp nerdctl_${NERDCTL_VER}_linux_${ARCH}.deb /var/cache/apt/archives

# Build and package buildkit with configuration
RUN git clone --branch v${BUILDKIT_VER} https://github.com/moby/buildkit.git /opt/buildkit-source
WORKDIR /opt/buildkit-source
RUN mkdir -p buildkit_deb/usr/bin && \
    CGO_ENABLED=1 go build -o bin/buildkitd ./cmd/buildkitd && \
    CGO_ENABLED=1 go build -o bin/buildctl ./cmd/buildctl && \
    cp bin/buildkitd bin/buildctl buildkit_deb/usr/bin/ && mkdir -p buildkit_deb/DEBIAN

# Add buildkit.service and buildkit.socket to the package
RUN mkdir -p buildkit_deb/lib/systemd/system && \
    cp examples/systemd/system/buildkit.service buildkit_deb/lib/systemd/system/ && \
    cp examples/systemd/system/buildkit.socket buildkit_deb/lib/systemd/system/

# Add post-install script for buildkit
RUN echo '#!/bin/bash' > buildkit_deb/DEBIAN/postinst && \
    echo 'set -e' >> buildkit_deb/DEBIAN/postinst && \
    echo 'mkdir -p /etc/buildkit' >> buildkit_deb/DEBIAN/postinst && \
    echo 'cat <<EOF > /etc/buildkit/buildkitd.toml' >> buildkit_deb/DEBIAN/postinst && \
    echo '[worker.oci]' >> buildkit_deb/DEBIAN/postinst && \
    echo '  enabled = false' >> buildkit_deb/DEBIAN/postinst && \
    echo '[worker.containerd]' >> buildkit_deb/DEBIAN/postinst && \
    echo '  enabled = true' >> buildkit_deb/DEBIAN/postinst && \
    echo '  namespace = "k8s.io"' >> buildkit_deb/DEBIAN/postinst && \
    echo 'EOF' >> buildkit_deb/DEBIAN/postinst && \
    echo 'cp /usr/bin/buildkitd /usr/local/bin/buildkitd' >> buildkit_deb/DEBIAN/postinst && \
    echo 'cp /usr/bin/buildctl /usr/local/bin/buildctl' >> buildkit_deb/DEBIAN/postinst && \
    echo 'systemctl daemon-reload' >> buildkit_deb/DEBIAN/postinst && \
    echo 'systemctl enable --now buildkit.service' >> buildkit_deb/DEBIAN/postinst && \
    chmod +x buildkit_deb/DEBIAN/postinst

COPY control-files/control-buildkit buildkit_deb/DEBIAN/control
RUN ARCH=$(dpkg --print-architecture) && \
    mv buildkit_deb buildkit_${BUILDKIT_VER}_linux_${ARCH} && \
    dpkg-deb --build buildkit_${BUILDKIT_VER}_linux_${ARCH}
RUN cp buildkit_${BUILDKIT_VER}_linux_${ARCH}.deb /var/cache/apt/archives

# Build and package k9s
RUN mkdir -p k9s_deb/usr/bin && mkdir -p k9s_deb/DEBIAN
RUN ARCH=$(dpkg --print-architecture) && \
    K9S_LATEST_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//') && \
    curl -L https://github.com/derailed/k9s/releases/download/v${K9S_LATEST_VER}/k9s_Linux_${ARCH}.tar.gz | tar -xz && \
    cp k9s k9s_deb/usr/bin && \
    mkdir -p k9s_deb/DEBIAN && \
    echo "Package: k9s" > k9s_deb/DEBIAN/control && \
    echo "Version: ${K9S_LATEST_VER}" >> k9s_deb/DEBIAN/control && \
    echo "Architecture: ${ARCH}" >> k9s_deb/DEBIAN/control && \
    echo "Maintainer: YourName <youremail@example.com>" >> k9s_deb/DEBIAN/control && \
    echo "Description: K9s Kubernetes CLI tool" >> k9s_deb/DEBIAN/control && \
    mv k9s_deb k9s_${K9S_LATEST_VER}_linux_${ARCH} && \
    dpkg-deb --build k9s_${K9S_LATEST_VER}_linux_${ARCH}
RUN ARCH=$(dpkg --print-architecture) && \
    K9S_LATEST_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//') && \
    cp k9s_${K9S_LATEST_VER}_linux_${ARCH}.deb /var/cache/apt/archives

WORKDIR /var/cache/apt/archives
RUN dpkg-scanpackages . /dev/null | gzip -9c >/opt/Packages.gz

WORKDIR /var/cache/apt
COPY scripts/create-apt-get-install-with-version.sh .
RUN bash create-apt-get-install-with-version.sh >/opt/apt-get-install-with-version.sh
