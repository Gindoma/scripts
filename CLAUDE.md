# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Arch Sovereign** is a documentation and automation project for building a radical, security-hardened Arch Linux installation optimized for AMD hardware. The core philosophy is **strict data separation**: the OS at `/` is disposable, while user data at `/data` is persistent and protected.

The project revolves around **CALI** (Clean Arch Linux Installer), a Bash-based automated installer script that implements:
- Full-disk encryption (LUKS2) with LVM
- Security hardening (AppArmor, UFW, DNS-over-TLS, kernel restrictions)
- AMD-optimized package selection (amdgpu, mesa, vulkan-radeon)
- Pure TTY boot (no display manager)
- Data vault architecture with symlinked user directories

## Repository Structure

```
.
├── install_script/     # CALI installer (install.sh) and its documentation
├── README.md           # Project overview and philosophy
└── CLAUDE.md           # This file
```

**Note:** Planned directories like `configs/` (Hyprland/Waybar) and `backup_scripts/` do not yet exist.

## Working with the Installer Script

### Key Script Files
- `install_script/install.sh` - The original V40 installer (~399 lines)
- `install_script/install-v41.sh` - **RECOMMENDED** V41 installer (~582 lines)
  - Enhanced security with input validation
  - Parallel downloads during disk operations
  - Improved UX with upfront configuration wizard
  - See `install_script/CHANGELOG-V41.md` for details

### Script Architecture (V40)

The V40 installer is structured in 9 sequential phases:

1. **Initialization** (lines 171-186): Internet check, pacman setup, cleanup
2. **Disk Selection** (lines 189-209): Interactive disk picker
3. **Configuration** (lines 212-227): Hostname, username, partition sizes, VM detection
4. **Partitioning** (lines 229-245): GPT setup, LUKS encryption
5. **LVM Setup** (lines 248-254): Physical volumes, volume group (vg0), logical volumes
6. **Formatting** (lines 257-266): Filesystem creation and mounting
7. **Installation** (lines 269-273): `pacstrap` with AMD packages (uses "cinema mode")
8. **System Configuration** (lines 276-371): Chroot operations via generated script
9. **Passwords & Summary** (lines 374-398): Credential setup and completion

### Important Implementation Details

**UI Functions (lines 21-152):**
- `run_task_cinema()`: Animated progress with movie quotes - used for long operations
- `run_task()`: Standard spinner for quick tasks
- Both functions log to `/tmp/arch-install.log` and exit on failure

**Volume Group:** Hardcoded as `vg0` (line 182)

**Partition Detection:** Handles NVMe vs SATA naming (line 237)
```bash
if [[ $DISK == *"nvme"* ]]; then PART1="${DISK}p1"; PART2="${DISK}p2"
else PART1="${DISK}1"; PART2="${DISK}2"; fi
```

**VM Support:** When `IS_VM == "y"`, uses virtio modules instead of amdgpu (lines 278-282)

**Data Partition Security:** `/data` is mounted with `noexec` flag (line 266) to prevent malware execution

**Generated Chroot Script (lines 285-367):**
- Creates `/mnt/setup_internal.sh` for chroot operations
- Handles locale (German/Vienna), users, ZSH config, LazyVim, symlinks, GRUB
- Security: AppArmor kernel params, UFW rules, DNS-over-TLS (Quad9)

### Modifying the Installer

**When adding packages:**
- Update the `pacstrap` command at line 271
- For AMD-specific packages, check VM mode compatibility

**When changing security settings:**
- Kernel parameters: Modify GRUB_CMDLINE_LINUX_DEFAULT at line 357
- Firewall rules: Update ufw commands at lines 337-338
- DNS settings: Edit resolved.conf generation at lines 333-335

**When adjusting partitioning:**
- LVM creation logic: lines 251-253
- Remember to update both formatting (lines 258-261) and mounting (lines 263-266)

### V41 Architecture & Improvements

**V41 introduces major enhancements over V40:**

**Security Improvements:**
- **Input validation functions** (lines 38-98):
  - `validate_hostname()`: Prevents command injection via regex
  - `validate_username()`: Blocks reserved names and invalid chars
  - `validate_password_strength()`: Enforces 12+ chars, warns on weak passwords
  - `validate_number()`: Range checking for partition sizes
- **Enhanced kernel hardening**: `kptr_restrict=2`, `unprivileged_bpf_disabled=1`, `bpf_jit_harden=2`
- **Mandatory confirmation**: Requires typing "YES" before disk wipe
- **Pre-collected LUKS password**: No interactive prompts during disk operations

**Performance Optimizations:**
- **Parallel downloads** (line 456): `pacman -Sw` runs during LVM setup
- **Background LazyVim clone** (line 485): Git clone during pacstrap
- **Estimated time savings**: 2-5 minutes on slow connections

**UX Improvements:**
- **Configuration wizard** (Phase 2): All user inputs collected upfront
- **Phase counter**: `[Phase X/9]` in headers
- **Confirmation screen** (Phase 3): Full summary before destruction
- **Unattended installation**: After confirmation, no interrupts
- **Enhanced error messages**: Validation functions provide specific feedback

**Key Architectural Changes:**
```
V40 Flow: Init → Disk → Config → Partition (with interrupts)
V41 Flow: Init → Config Wizard → Confirmation → Unattended Install
```

**Modifying V41:**
- Validation functions are in lines 38-98 (before any operations)
- All user inputs now have validation - modify regex patterns carefully
- Parallel operations use background PIDs - check `wait` calls if changing order
- Passwords are stored in variables and piped to commands (not interactive)

### Testing

The installer is designed to run on:
- Bare metal AMD systems (primary use case)
- QEMU/KVM VMs (via `IS_VM` flag)

**Quick VM Test Commands:**
```bash
# V41 (recommended):
bash /path/to/install-v41.sh

# V40 (legacy):
curl -L https://raw.githubusercontent.com/Gindoma/scripts/main/install.sh | bash
```

## Security Architecture

**Encryption Stack:**
- LUKS2 → LVM → Logical Volumes
- Password prompted twice during install (format + open)

**Hardening Features:**
- AppArmor LSM with profiles loaded at boot
- UFW: default deny incoming, allow outgoing
- DNS-over-TLS via systemd-resolved (Quad9: 9.9.9.9)
- `kernel.dmesg_restrict = 1` via sysctl
- `/data` mounted with `noexec`

**Data Separation Philosophy:**
User home subdirectories are symlinks to `/data`:
- `~/Downloads` → `/data/Downloads`
- `~/Documents` → `/data/Dokumente`
- `~/Pictures` → `/data/Bilder`
- `~/Videos` → `/data/Videos`
- `~/Projects` → `/data/Projects`

This allows OS reinstallation without data loss.

## Development Tools & Environment

**Pre-installed Stack:**
- Shell: ZSH with autosuggestions + syntax highlighting
- Editor: Neovim with LazyVim starter (cloned from GitHub, .git removed)
- Containers: Docker service enabled
- Language tools: npm, git, ripgrep, fd
- AMD Graphics: mesa, vulkan-radeon, libva-mesa-driver

**ZSH Config (lines 312-328):**
- Minimalist prompt: `[user@host] ~/path >`
- Vi keybindings (`bindkey -v`)
- Auto-cd enabled
- History: 1000 lines in `~/.zsh_history`

## Project Status (As of README)

**Completed:**
- CALI V40 installer with cinema mode and error handling
- Base security stack (AppArmor, UFW, DNS-over-TLS)
- Shell environment and Neovim setup
- VM testing capability

**In Progress:**
- Dotfiles management for Hyprland/Waybar
- Hyprland rice customization
- Gaming setup (Steam/Lutris via Flatpak)

**Planned:**
- Automated `/data` backups
- Custom Arch ISO with CALI embedded

## Conventions

**Language/Locale:** German (de_DE.UTF-8), Vienna timezone, de-latin1 keymap

**User Permissions:** Default user added to: wheel, video, audio, storage, docker

**Package Manager:** Pacman with ParallelDownloads=10 and ILoveCandy easter egg

**Bootloader:** GRUB with quiet boot, AppArmor parameters, cryptdevice UUID

## Notes for Future Development

- The installer has no rollback mechanism; failures are logged to `/tmp/arch-install.log`
- The `configs/` directory mentioned in README doesn't exist yet - this is the target for Hyprland dotfiles
- The script assumes UEFI boot (no legacy BIOS support)
- All interactive prompts (hostname, username, passwords) happen upfront; installation runs unattended after disk wipe confirmation
