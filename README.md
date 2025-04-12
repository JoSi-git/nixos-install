# NixOS Interactive Installation Script

This repository provides an interactive installation script for NixOS that can be executed from the minimal USB environment. The script supports two installation modes:

- **Full Disk Reformat:** Overwrites the entire disk (single-boot).
- **Multiboot Setup:** Allows you to select and optionally format specific partitions for NixOS while preserving an existing system.

> **Warning:** This script performs destructive operations. Back up all important data before proceeding.

## Overview

The installation process involves the following steps:

1. **Boot into the Minimal NixOS Environment:**  
   Make sure your system is booted using the NixOS minimal USB image.

2. **Temporarily Install Git:**  

   Since Git is usually not included in the minimal environment, use `nix-shell` to temporarily install it.

3. **Clone and Update the Repository:**  
   Use Git to clone the repository and update it if necessary.

4. **Run the Installation Script:**  
   Execute the provided script and follow the interactive prompts to choose your installation mode and partition configuration.

## Detailed Instructions

### 1. Boot into the Minimal NixOS Environment

Boot your system from the NixOS minimal USB image. Ensure you have a working network connection for the installation.

### 2. Temporarily Install Git

The minimal environment may not have Git pre-installed. To install it temporarily, run:

```sh
nix-shell -p git --run "echo 'Git is temporarily available.'"
```

This command opens a temporary shell that includes Git. You can now execute Git commands from this shell.

### 3. Clone and Update the Repository

Clone the repository to a temporary directory:

```sh
git clone https://github.com/JoSi-git/nixos-install.git /tmp/nixos-install
```

Change into the repository directory:

```sh
cd /tmp/nixos-install
```

Before running the installation script, pull the latest updates:

```sh
git pull
```

### 4. Run the Installation Script

Execute the installation script by running:

```sh
sh install.sh
```

The script will guide you through the following steps:

- **Device Selection:**  
  It will list all attached storage devices and prompt you to select the target disk for installation.

- **Installation Mode:**  
  Choose between:
  - **Mode 1:** Full Disk Reformat – repartitions the entire disk (all data will be lost).
  - **Mode 2:** Multiboot – manually select and optionally format individual partitions (such as root, swap, and EFI).

- **Partition Configuration:**  
  You will be prompted to provide information such as swap size and decide whether to format each partition.

- **Configuration and Final Installation:**  
  The script generates a NixOS configuration file and opens it for editing (using `nano`). After editing, it installs NixOS, prompts you to remove the installation media, and reboots.
