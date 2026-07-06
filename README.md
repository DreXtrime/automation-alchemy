# Infrastructure Insight

A containerized infrastructure monitoring application deployed across a multiserver virtual environment. A diagnostic
frontend displays live system metrics served by a backend API, distributed across two web servers behind a load
balancer.

---

## Architecture

<!-- SVG diagram placeholder -->

![Diagram](assets/diagram.svg)

| VM           | IP            | Role                                              |
|--------------|---------------|---------------------------------------------------|
| loadbalancer | 192.168.56.10 | Nginx reverse proxy, distributes traffic          |
| webserver01  | 192.168.56.11 | Frontend container, serves UI and proxies metrics |
| webserver02  | 192.168.56.12 | Frontend container, serves UI and proxies metrics |
| appserver    | 192.168.56.20 | Backend container, exposes `/metrics` API         |
| backup       | 192.168.56.30 | Automated weekly backups via rsync                |

---

## Objectives

- Deploy a containerized application across a multiserver infrastructure
- Configure a load balancer to distribute traffic between two web servers
- Develop a frontend and backend application that displays live infrastructure metrics
- Secure all servers with firewall rules, SSH hardening, and Fail2Ban
- Automate weekly backups of application data, `/home`, and `/etc`

---

- [Architecture](#architecture)
- [Objectives](#objectives)
- [System Requirements](#system-requirements)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
  - [Apt Cache (Optional)](#apt-cache-optional)
- [Setup and Installation](#setup-and-installation)
- [Accessing the Application](#accessing-the-application)
- [Quick SSH Access](#quick-ssh-access)
- [Verifying the Infrastructure](#verifying-the-infrastructure)
  - [Server communication](#server-communication)
  - [Containerization tools](#containerization-tools)
  - [Firewall rules](#firewall-rules)
  - [Load balancer configuration](#load-balancer-configuration)
- [Application](#application)
  - [Backend](#backend)
  - [Frontend](#frontend)
  - [Containerization](#containerization)
- [Load Balancing](#load-balancing)
  - [Weighted Round-Robin](#weighted-round-robin)
- [Backup](#backup)
  - [What is backed up](#what-is-backed-up)
  - [Schedule](#schedule)
  - [Running a manual backup](#running-a-manual-backup)
  - [Restoring from backup](#restoring-from-backup)
- [Security](#security)
- [Bonus Features](#bonus-features)
- [Project Structure](#project-structure)
- [Author](#author)

---

## System Requirements

- At least 16GB RAM (each VM uses between 1-2GB)
- At least 20GB free disk space

## Prerequisites

Before running `vagrant up`, make sure you have the following installed and configured on your host machine:

- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (optional, for apt cache)

Generate the required SSH keys:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/devops_key -N ""
ssh-keygen -t ed25519 -f ~/.ssh/backup_key -N ""
```

Copy `.env.example` to `.env` and fill in the required values:

```bash
cp .env.example .env
```

---

## Configuration

`.env` reference:

| Variable          | Required | Description                                            |
|-------------------|----------|--------------------------------------------------------|
| `DEVOPS_PASSWORD` | Yes      | Password for the devops user on all VMs                |
| `APT_CACHE_URL`   | No       | URL of an apt-cacher-ng proxy to speed up provisioning |

### Apt Cache (Optional)

Provisioning requires downloading packages on every VM. Without a cache each VM downloads the same packages
independently, which is slow. An apt-cacher-ng proxy caches packages on the first download and serves them locally for
all subsequent requests, significantly speeding up provisioning especially when rebuilding VMs frequently.

If `APT_CACHE_URL` is not set in `.env` provisioning works normally, just without the cache benefit.

To use the optional apt cache, start the container on your host machine first:

```bash
docker run -d \
    --name apt-cache \
    --restart unless-stopped \
    -p 3142:3142 \
    -v apt-cache-data:/var/cache/apt-cacher-ng \
    sameersbn/apt-cacher-ng
```

Then set in `.env`:

```
APT_CACHE_URL=http://192.168.56.1:3142
```

---

## Setup and Installation

```bash
vagrant up
```

Vagrant will provision all five VMs in order. The full setup takes around 10-15 minutes depending on your internet
connection.

To provision a single VM:

```bash
vagrant up loadbalancer
```

To destroy all VMs:

```bash
vagrant destroy -f
```

---

## Accessing the Application

Once provisioned, open your browser and navigate to:

```
http://192.168.56.10
```

The load balancer distributes requests between webserver01 and webserver02. Refreshing the page will alternate the "
Served by" hostname between the two web servers, confirming the load balancer is working.

To fetch raw metrics from the load balancer:

```bash
curl http://192.168.56.10/metrics
```
---
## Quick SSH Access

A Windows Terminal helper script is included that opens SSH sessions to all five VMs in a single split-pane window.

Run it from the project root:

```bat
.\terminal.cmd
```

This opens five panes simultaneously, one per VM, using the devops key for authentication. Requires Windows Terminal to be installed.

To SSH into a single VM manually:

```bash
ssh -i ~/.ssh/devops_key devops@192.168.56.10
```

| VM           | IP            |
|--------------|---------------|
| loadbalancer | 192.168.56.10 |
| webserver01  | 192.168.56.11 |
| webserver02  | 192.168.56.12 |
| appserver    | 192.168.56.20 |
| backup       | 192.168.56.30 |

---

## Verifying the Infrastructure

### Server communication

Ping each server from the others to confirm connectivity:

```bash
ssh -i ~/.ssh/devops_key devops@192.168.56.11
ping appserver
ping loadbalancer
ping webserver02
ping backup
```

### Containerization tools

Check Docker is installed on the app server and web servers:

```bash
ssh -i ~/.ssh/devops_key devops@192.168.56.20
docker --version
docker ps
```

### Firewall rules

Check UFW rules on any server:

```bash
sudo ufw status verbose
```

### Load balancer configuration

```bash
ssh -i ~/.ssh/devops_key devops@192.168.56.10
cat /etc/nginx/nginx.conf
sudo systemctl status nginx
```

Refresh `http://192.168.56.10` interface multiple times and the "Served by" field alternates between webserver01 and
webserver02 automatically.

---

## Application

The monitoring application is maintained as a separate public
repository: [simple-infra-monitor](https://github.com/DreXtrime/simple-infra-monitor)

### Backend

Runs on the app server as a Flask API. Exposes two endpoints:

- `GET /metrics` - returns hostname, OS type, OS version, CPU usage, CPU count, memory usage, memory used, and memory
  total as JSON
- `GET /health` - returns `{"status": "ok"}`

### Frontend

Runs on each web server as a Flask app. Serves a dashboard that:

- Calls the backend `/metrics` endpoint and proxies the data
- Adds its own hostname as the responding web server
- Auto-refreshes every 5 seconds with a pause/resume control
- Works on all screen sizes

### Containerization

Both components have separate Dockerfiles and are published to GitHub Container Registry:

```bash
docker images
docker inspect <image_id>
```

Images are pulled directly from the registry during provisioning:

```
ghcr.io/drextrime/infra-backend:latest
ghcr.io/drextrime/infra-frontend:latest
```

---

## Load Balancing

Nginx is configured as a reverse proxy with round-robin load balancing (default):

```nginx
upstream webservers {
    server 192.168.56.11:8080;
    server 192.168.56.12:8080;
}
```

### Weighted Round-Robin

To distribute more traffic to one server, add weights:

```nginx
upstream webservers {
    server 192.168.56.11:8080 weight=3;
    server 192.168.56.12:8080 weight=1;
}
```

To route each new request to whichever server has fewer active connections:

```nginx
upstream webservers {
    least_conn;
    server 192.168.56.11:8080;
    server 192.168.56.12:8080;
}
```

webserver01 receives 3 out of every 4 requests. Useful when servers have different hardware capabilities.

To change the default config edit it at `scripts/loadbalancer.sh`.

---

## Backup

A dedicated backup VM at `192.168.56.30` performs weekly full backups of all servers using rsync over SSH.

### What is backed up

- `/etc` - system configuration
- `/home/devops` - devops user home directory

### Schedule

Backups run every Sunday at 02:00 as the devops user. To verify, inside `backup` VM run:

```bash
crontab -l
```

### Running a manual backup

```bash
sudo /opt/backup.sh
ls /opt/backups/
```

### Restoring from backup

```bash
sudo /opt/restore.sh <date> <server>
# Example:
sudo /opt/restore.sh 2026-01-01 appserver
```

---

## Security

All servers are hardened with the following:

- Root login disabled
- Password authentication disabled, SSH key only
- UFW configured to deny all incoming traffic except what is explicitly needed
- Fail2Ban configured to ban IPs after 5 failed SSH attempts
- Automatic security updates enabled
- Secure umask set for all users
- Dedicated backup SSH key with rsync-only sudo access

---

## Bonus Features

### Apt Cache
An optional apt-cacher-ng proxy can be configured via in `.env` to cache package downloads during provisioning. This significantly speeds up rebuilding VMs.

### Windows Terminal Quick Connect
A `terminal.cmd` script opens SSH sessions to all five VMs in a single Windows Terminal split pane window. See the [Quick SSH Access](#quick-ssh-access) section for details.

### Published Docker Images
The monitoring application is maintained as a separate public repository with its own CI/CD pipeline. On every push to main, GitHub Actions runs automated tests against both the frontend and backend, builds the Docker images, and publishes them to GitHub Container Registry. The provisioning scripts pull the pre-built images directly from the registry rather than building on each VM.

- [simple-infra-monitor](https://github.com/DreXtrime/simple-infra-monitor)
- `ghcr.io/drextrime/infra-backend:latest`
- `ghcr.io/drextrime/infra-frontend:latest`

___

## Project Structure

```
infrastructure-insight/
├── Vagrantfile
├── .env.example
├── .gitignore
├── terminal.cmd          # opens windows terminal and sets up ssh to all VMs
└── scripts/
    ├── provision.sh      # runs on every VM: users, SSH, UFW, Fail2Ban
    ├── docker.sh         # installs Docker on app server and web servers
    ├── frontend.sh       # pulls and runs the frontend container
    ├── backend.sh        # pulls and runs the backend container
    ├── loadbalancer.sh   # installs and configures Nginx
    └── backup.sh         # sets up backup scripts and cron job
```

## Author

[tanelerikneitov](https://github.com/DreXtrime)