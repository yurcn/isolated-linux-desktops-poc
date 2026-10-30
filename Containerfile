FROM ubuntu:24.04

ARG KUBECTL_VERSION=v1.37.0
ARG HELM_VERSION=v3.19.0

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-terminal \
        dbus-x11 \
        x11-xserver-utils \
        thunar \
        gvfs \
        gvfs-backends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        git \
        openssh-client \
        rsync \
        vim \
        less \
        procps \
        iproute2 \
        iputils-ping \
        dnsutils \
        mesa-utils \
        libgl1-mesa-dri \
        libglx-mesa0 \
        fonts-liberation \
        fonts-dejavu-core \
        fonts-dejavu \
        fonts-dejavu-core \
        fonts-dejavu-extra \
        fonts-dejavu-mono \
        fonts-droid-fallback \
        fonts-font-awesome \
        fonts-freefont-ttf \
        fonts-liberation \
        fonts-liberation2 \
        fonts-montserrat \
        fonts-noto-color-emoji \
        fonts-noto-mono \
        fonts-open-sans \
        fonts-opensymbol \
        fonts-urw-base35 \
        jq \
        ansible \
        awscli \
        s3cmd \
        restic \
        python3-openstackclient \
        bash-completion \
        git-lfs \
        make \
        locales \
        mousepad \
        iproute2 \
        isc-dhcp-client \
        iputils-ping \
        mariadb-client-core \
        openssh-client ipcalc \
        lftp net-tools flameshot \
        bind9-dnsutils postgresql-client-common \
        sudo && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/network
RUN printf '%s\n' \
    'auto lo' \
    'iface lo inet loopback' \
    '' \
    'auto eth0' \
    'iface eth0 inet dhcp' \
    > /etc/network/interfaces

RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
        -o /usr/local/bin/kubectl && \
    chmod 0755 /usr/local/bin/kubectl

RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL \
        "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
        -o /tmp/helm.tar.gz && \
    tar -xzf /tmp/helm.tar.gz -C /tmp && \
    install -m 0755 \
        "/tmp/linux-${ARCH}/helm" \
        /usr/local/bin/helm && \
    rm -rf /tmp/helm.tar.gz "/tmp/linux-${ARCH}"

RUN set -eux; \
    mkdir -p /opt/local; \
    if getent group 1001 >/dev/null; then \
        old_group="$(getent group 1001 | cut -d: -f1)"; \
        if [ "$old_group" != "desktop" ]; then \
            groupmod -n desktop "$old_group"; \
        fi; \
    else \
        groupadd -g 1001 desktop; \
    fi; \
    \
    if getent passwd 1001 >/dev/null; then \
        old_user="$(getent passwd 1001 | cut -d: -f1)"; \
        if [ "$old_user" != "desktop" ]; then \
            usermod \
                -l desktop \
                -d /home/desktop \
                -m \
                "$old_user"; \
        fi; \
        usermod \
            -g 1001 \
            -s /bin/bash \
            desktop; \
    else \
        useradd \
            -m \
            -u 1001 \
            -g 1001 \
            -s /bin/bash \
            desktop; \
    fi

RUN id desktop && \
    getent passwd desktop && \
    getent group desktop && \
    test "$(id -u desktop)" = "1001" && \
    test "$(id -g desktop)" = "1001"

COPY container-entrypoint /usr/local/bin/container-entrypoint
RUN chmod 0755 /usr/local/bin/container-entrypoint

ENTRYPOINT ["/usr/local/bin/container-entrypoint"]

