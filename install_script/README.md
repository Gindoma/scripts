# 🛡️ CALI: Clean Arch Linux Installer

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-40.0-blue?style=for-the-badge)

> **"Simplicity is the ultimate sophistication."**
> An automated, hardened, and opinionated installer for a pure Arch Linux experience.

---

## 📖 Overview

**CALI** (Clean Arch Linux Installer) turns the daunting task of a manual Arch Linux installation into a streamlined, cinematic experience. It builds a **production-grade, encrypted, and secure** foundation in minutes, leaving you with a clean slate (TTY) optimized for performance.

Designed for **AMD Hardware** and **Power Users** who value security and data integrity.

---

## ✨ Key Features

### 🔒 Security First
* **Full Disk Encryption:** LUKS2 encryption for the entire physical volume.
* **LVM Architecture:** Flexible logical volume management (`vg0`).
* **Data Separation:** Unique `/data` partition mounted with `noexec` flag for maximum security against malware execution in user directories.
* **Hardened Kernel:** `dmesg` restricted, AppArmor enabled, UFW firewall pre-configured (Default Deny).
* **Privacy:** DNS-over-TLS (DoT) enabled via Quad9 by default.

### 🚀 Performance & Core
* **Parallel Downloads:** Pacman optimized for 10 simultaneous threads.
* **AMD Optimized:** Pre-installed `mesa`, `vulkan-radeon`, and `amd-ucode`.
* **Pure Experience:** No bloat. No Display Manager. No Desktop Environment. Just a pure TTY waiting for your command.

### 🛠️ Developer Ready
* **ZSH Pre-configured:** Syntax highlighting, autosuggestions, and a clean prompt out of the box.
* **LazyVim:** Neovim configured with the LazyVim starter template.
* **Containerization:** Docker and Flatpak installed and configured.

---

## 💾 Partition Layout

The script implements a robust separation of System and Data:

| Partition | Mount Point | FS Type | Size | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Part 1** | `/boot` | FAT32 | 512M | EFI System Partition |
| **Part 2** | *Encrypted* | LUKS2 | Rest | Physical Volume for LVM |
| ↳ **LVM** | `swap` | SWAP | User | System Swap |
| ↳ **LVM** | `/` | EXT4 | User | System Root (OS & Configs) |
| ↳ **LVM** | `/data` | EXT4 | Rest | **Persistent Data Storage** |

> **Note:** User folders (`Downloads`, `Documents`, `Projects`) are symbolic links pointing to `/data`. This allows you to nuke the root system without losing your personal files.

---

## ⚡ Installation

### 1. Download Arch ISO
Boot your machine using the latest [Arch Linux ISO](https://archlinux.org/download/).

### 2. Run the Installer
Connect to the internet and run the following command:

```bash
curl -L https://raw.githubusercontent.com/Gindoma/scripts/main/install.sh | bash
