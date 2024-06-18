---
title: "Docker"
date: 2024-06-18T23:03:02+05:00
tags: [ "docker" ]
categories: [ "guide" ]
---

### Installation
For the most default installation, you can use the official Docker installation script.
This script will add the Docker repository to your system and install the latest version of Docker.

> Notice that the scripts are not recommended for production environments.
```bash
curl -fsSL https://get.docker.com | sudo sh
```

### Rootless Installation
Rootless Installation requires a few more steps than the default installation.

Enable lingering for your user:
```bash
sudo loginctl enable-linger $USER
```
Set `XDG_RUNTIME_DIR` variable to avoid systemd issues:
```bash
export "XDG_RUNTIME_DIR=/run/user/$(id -u)"
```
Install Rootless Docker along alongside Rootful Docker:
```bash
dockerd-rootless-setuptool.sh install
```
Install Rootless Docker standalone:
```bash
curl -fsSL https://get.docker.com/rootless | sh
```

### Configuration
By default, dockerd doesn't limit container logs. 
You can limit the log size by adding the following configuration to the daemon.json file:
```bash
sudo nano /etc/docker/daemon.json
```
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "1m",
    "max-file": "3"
  }
}
```
```bash
sudo systemctl restart docker
```
These changes don't affect the already existing containers.
You may want to purge all containers
> The command below will remove all containers, including running ones.
```bash
docker ps -aq | xargs docker rm -f
```

### Rootless Configuration
Rootless Docker has a different configuration file.
You can find the configuration file in the following path:
```bash
mkdir -p ~/.config/docker
nano ~/.config/docker/daemon.json
```
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "1m",
    "max-file": "3"
  }
}
```
```bash
export "XDG_RUNTIME_DIR=/run/user/$(id -u)"
systemctl --user restart docker
```
Purging containers is the same as the rootful configuration:
> The command below will remove all containers, including running ones.
```bash
docker ps -aq | xargs docker rm -f
```

### docker compose vs docker-compose
`docker-compose` is deprecated in favor of `docker compose`. Prefer using the new command. It's installed by default with the scripts above.
