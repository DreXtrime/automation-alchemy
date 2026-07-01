#!/bin/bash
set -e
DEVOPS_PUB_KEY=$1
DEVOPS_PASSWORD=$2

# Update and upgrade packages
# TODO enable after done with dev
# apt-get update -y
# apt-get full-upgrade -y

# Create devops user only if it doesn't exist
if ! id devops &>/dev/null; then
    useradd -m -s /bin/bash -G sudo devops
fi

# Set up SSH key authentication for devops
mkdir -p /home/devops/.ssh
if ! grep -qF "$DEVOPS_PUB_KEY" /home/devops/.ssh/authorized_keys 2>/dev/null; then
    echo "$DEVOPS_PUB_KEY" >> /home/devops/.ssh/authorized_keys
fi
chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys

# Require password for sudo
sed -i '/exempt_group/d' /etc/sudoers

# Configure SSH
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
if ! grep -q "AllowUsers devops" /etc/ssh/sshd_config; then
    echo "AllowUsers devops" >> /etc/ssh/sshd_config
fi

# Remove cloud-init SSH override
echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/50-cloud-init.conf
systemctl restart ssh

# Set secure umask for all users
if ! grep -q "umask 027" /etc/profile; then
    echo "umask 027" >> /etc/profile
fi

# Enable automatic security updates
apt-get install -y unattended-upgrades
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades

# Configure UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# Add hostname resolution only if not already present
if ! grep -q "loadbalancer" /etc/hosts; then
    cat >> /etc/hosts << EOF
192.168.56.10 loadbalancer
192.168.56.11 webserver01
192.168.56.12 webserver02
192.168.56.20 appserver
EOF
fi

# Set devops password
echo "devops:$DEVOPS_PASSWORD" | chpasswd

# Install and configure Fail2Ban
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
ignoreip = 192.168.56.1/32
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
systemctl enable fail2ban
systemctl restart fail2ban