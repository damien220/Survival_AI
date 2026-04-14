# Docker Engine — Linux Offline Installation

This directory holds the Docker static binary archive for offline installation on Linux.

Download it first (on an internet-connected machine):
```bash
./scripts/download-docker.sh --linux
```

---

## Install from Static Binaries (No Package Manager)

Suitable for any Linux x86_64 system. No `apt` or `yum` required.

```bash
# 1. Extract the archive
tar xzf docker-*-static-x64.tgz

# 2. Copy binaries to a system path
sudo cp docker/* /usr/local/bin/

# 3. Start Docker daemon (run as root or with sudo)
sudo dockerd &

# 4. Verify
docker run hello-world
```

To start dockerd automatically on login (without systemd):
```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &
```

---

## Install via Package Manager (Ubuntu/Debian — requires packages)

If you can download .deb packages on an internet machine and transfer them:

```bash
# On the internet machine, download the packages
apt-get download docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Transfer the .deb files to the offline machine, then install:
sudo dpkg -i *.deb
sudo systemctl enable --now docker
```

---

## Install via Package Manager (CentOS/RHEL/Fedora)

```bash
# Download on internet machine
yumdownloader --resolve docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Transfer .rpm files, then install:
sudo rpm -ivh *.rpm
sudo systemctl enable --now docker
```

---

## Post-Installation

Add your user to the `docker` group to run Docker without `sudo`:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

After Docker is installed, return to the project and run:
```bash
./scripts/setup.sh
```
