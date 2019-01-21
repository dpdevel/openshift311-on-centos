Install OKD 3.x on your development box.

This repository is a set of scripts that will allow you easily install the latest version (3.11) of OKD in a single node fashion.  What that means is that all of the services required for OKD to function (master, node, etcd, etc.) will all be installed on a single host.  The script supports a custom hostname which you can provide using the interactive mode.

**Please do use a clean CentOS system, the script installs all necesary tools and packages including Ansible, container runtime, etc.**

## Installation

1. Create a VM with CentOs 7.5 (Minimal)

2. Clone this repo

```
git clone https://github.com/dpdevel/openshift311-on-centos.git
```

3. Execute the installation script

```
cd installcentos
./install-openshift.sh
```

## Automation
1. Define mandatory variables for the installation process

```
# Domain name to access the cluster
$ export DOMAIN=<public ip address>.nip.io

# User created after installation
$ export USERNAME=<current user name>

# Password for the user
$ export PASSWORD=password
```

2. Define optional variables for the installation process

```
# Instead of using loopback, setup DeviceMapper on this disk.
# !! All data on the disk will be wiped out !!
$ export DISK="/dev/sda"
```

3. Run the automagic installation script as root with the environment variable in place:

```
curl https://raw.githubusercontent.com/dpdevel/openshift311-on-centos/master/install-openshift.sh | INTERACTIVE=false /bin/bash
```

## Development

For development it's possible to switch the script repo

```
# Change location of source repository
$ export SCRIPT_REPO="https://raw.githubusercontent.com/dpdevel/openshift311-on-centos/master"
$ curl $SCRIPT_REPO/install-openshift.sh | /bin/bash
```
