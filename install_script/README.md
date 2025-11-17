# 🛡️ CALI: Clean Arch Linux Installer

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-41.0-blue?style=for-the-badge)

> **"Simplicity is the ultimate sophistication."**
> An automated, hardened, and opinionated installer for a pure Arch Linux experience.

**🆕 V41 Update**: Enhanced security with input validation, parallel downloads, and streamlined user experience!

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

## 🆚 Version Comparison: V40 vs V41

| Feature | V40 | V41 |
|---------|-----|-----|
| **Input Validation** | ❌ None | ✅ Complete (hostname, username, passwords) |
| **Password Strength Check** | ❌ | ✅ Min 12 chars, complexity check |
| **Confirmation Screen** | ⚠️ 2-second delay | ✅ Typed confirmation + full summary |
| **Parallel Downloads** | ❌ Sequential | ✅ During disk operations |
| **User Experience** | Interrupts during install | All inputs upfront |
| **Security Hardening** | Good | Enhanced (kernel hardening, UFW logging) |
| **Error Messages** | Generic | Specific validation feedback |
| **Install Time** | 15-20 min | 12-17 min (-20%) |
| **Code Lines** | 399 | 582 (+input safety) |

**Recommendation**: Use **V41** for production systems, V40 for quick testing.

---

## ⚡ Installation

### Choose Your Version

#### 🔒 V41 (Recommended - Hardened & Optimized)
```bash
curl -L https://raw.githubusercontent.com/YOUR_REPO/main/install_script/install-v41.sh -o install.sh
bash install.sh
```

#### 🚀 V40 (Legacy - Minimal)
```bash
curl -L https://raw.githubusercontent.com/Gindoma/scripts/main/install.sh | bash
