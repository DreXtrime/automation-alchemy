#!/bin/bash
set -e

# Install dependencies
if ! command -v git &>/dev/null; then
    apt-get install -y git
fi

apt-get install -y ca-certificates curl gnupg

# Add Dockers official GPG key
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Add Docker apt repository
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Install Docker
apt-get update -y
if ! command -v docker &>/dev/null; then
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add devops user to docker group so it can run docker without sudo
if ! groups devops | grep -q docker; then
    usermod -aG docker devops
fi