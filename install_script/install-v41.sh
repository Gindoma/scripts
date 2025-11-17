#!/bin/bash
set -e
set -o pipefail

# ==============================================================================
#  ARCH LINUX INSTALLER V41 (Optimized, Hardened, Parallel)
#  Improvements: Input Validation, Parallelization, Enhanced Security
# ==============================================================================

# --- COLORS ---
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
YELLOW=$(tput setaf 3)
GRAY=$(tput setaf 8)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
NC=$(tput sgr0)

# --- UI FUNCTIONS ---
COLS=$(tput cols)
LOG="/tmp/arch-install.log"

center() {
    local text="$1"
    local color="$2"
    local text_len=${#text}
    local padding=$(( (COLS - text_len) / 2 ))
    printf "%${padding}s" ""
    printf "${color}%s${NC}\n" "$text"
}

line() {
    printf "${GRAY}%*s${NC}\n" "$COLS" '' | tr ' ' '─'
}

box() {
    local phase="$1"
    local title="$2"
    local color="$3"
    clear
    echo ""
    line
    if [ -n "$phase" ]; then
        center "[Phase ${phase}/9] ${title}" "$color"
    else
        center "$title" "$color"
    fi
    line
    echo ""
}

# --- VALIDATION FUNCTIONS ---
validate_hostname() {
    local input="$1"
    [[ "$input" =~ ^[a-zA-Z0-9-]{1,63}$ ]] && return 0
    echo "${RED}✗ Invalid: Use only letters, numbers, and hyphens (max 63 chars)${NC}"
    return 1
}

validate_username() {
    local input="$1"
    if [[ ! "$input" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        echo "${RED}✗ Invalid: Must start with lowercase letter, max 32 chars${NC}"
        return 1
    fi
    if [[ "$input" == "root" ]] || [[ "$input" == "nobody" ]]; then
        echo "${RED}✗ Reserved username${NC}"
        return 1
    fi
    return 0
}

validate_number() {
    local input="$1"
    local min="$2"
    local max="$3"
    if [[ ! "$input" =~ ^[0-9]+$ ]]; then
        echo "${RED}✗ Must be a number${NC}"
        return 1
    fi
    if [ "$input" -lt "$min" ] || [ "$input" -gt "$max" ]; then
        echo "${RED}✗ Must be between $min and $max${NC}"
        return 1
    fi
    return 0
}

validate_password_strength() {
    local pass="$1"
    local len=${#pass}

    if [ "$len" -lt 12 ]; then
        echo "${RED}✗ Password too short (minimum 12 characters)${NC}"
        return 1
    fi

    if [[ ! "$pass" =~ [A-Z] ]] || [[ ! "$pass" =~ [a-z] ]] || [[ ! "$pass" =~ [0-9] ]]; then
        echo "${YELLOW}⚠ Weak: Should contain uppercase, lowercase, and numbers${NC}"
        read -p "Continue anyway? (y/n): " continue
        [[ "$continue" == "y" ]] || return 1
    fi

    return 0
}

# --- CINEMA MODE ---
run_task_cinema() {
    local message="$1"
    local command="$2"

    QUOTES=(
        "Wake up, Neo... (The Matrix)"
        "I'll be back. (Terminator)"
        "It's dangerous to go alone! Take this. (Zelda)"
        "May the Force be with you. (Star Wars)"
        "Winter is coming. (Game of Thrones)"
        "See you space cowboy... (Cowboy Bebop)"
        "The cake is a lie. (Portal)"
        "Protocol 3: Protect the Pilot. (Titanfall 2)"
        "Do. Or do not. There is no try. (Yoda)"
        "Loading reality... please wait."
        "Compiling the matrix..."
        "Hack the Planet! (Hackers)"
        "A wizard is never late. (LOTR)"
        "Installing Arch is cheaper than therapy."
        "Downloading the entire internet..."
        "Initializing flux capacitor..."
    )

    eval "$command" >> "$LOG" 2>&1 &
    local pid=$!

    local delay=0.1
    local quote_delay=0
    local spinstr='|/-\'
    local quote_index=0

    tput civis
    printf "  ${WHITE}%-40s${NC}" "$message"

    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [${CYAN}%c${NC}] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}

        if [ $quote_delay -eq 0 ]; then
            quote_index=$((RANDOM % ${#QUOTES[@]}))
            tput el
            printf "${GRAY}:: %s${NC}" "${QUOTES[$quote_index]}"
            quote_delay=50
        fi
        ((quote_delay--))

        sleep $delay
        printf "\r  ${WHITE}%-40s${NC}" "$message"
    done

    tput cnorm
    wait $pid
    local exit_code=$?
    tput el

    if [ $exit_code -eq 0 ]; then
        printf " [${GREEN}✓${NC}]\n"
    else
        printf " [${RED}✗${NC}]\n"
        echo -e "${RED}!!! ERROR DETECTED !!! Last lines of log:${NC}"
        tail -n 15 "$LOG"
        exit 1
    fi
}

# --- STANDARD SPINNER ---
run_task() {
    local message="$1"
    local command="$2"
    printf "  ${WHITE}%-50s${NC}" "$message"

    eval "$command" >> "$LOG" 2>&1 &
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'

    tput civis
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [${CYAN}%c${NC}]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    tput cnorm

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf " [${GREEN}✓${NC}]\n"
    else
        printf " [${RED}✗${NC}]\n"
        echo ""
        echo -e "${RED}!!! ERROR DETECTED !!! Check details below:${NC}"
        tail -n 15 "$LOG"
        exit 1
    fi
}

summary_item() {
    local key="$1"
    local val="$2"
    local dots="........................................"
    printf "   ${WHITE}%-18s ${GRAY}%s ${CYAN}%s${NC}\n" "$key" "${dots:0:$((22 - ${#key}))}" "$val"
}

cleanup() {
    if [ $? -ne 0 ]; then
        tput cnorm
        echo ""
        center "!!! SCRIPT INTERRUPTED !!!" "$RED"
        echo -e "${GRAY}Log saved at: $LOG${NC}"
        umount -R /mnt 2>/dev/null || true
        vgchange -an 2>/dev/null || true
        cryptsetup close cryptlvm 2>/dev/null || true
        swapoff -a 2>/dev/null || true
    fi
}
trap cleanup EXIT

START_TIME=$(date +%s)
rm -f "$LOG"

# ==============================================================================
# PHASE 0: WELCOME & PRE-FLIGHT
# ==============================================================================
box "" "ARCH LINUX INSTALLER V41" "$CYAN"
center "Security-Hardened | AMD-Optimized | Data-Vault Architecture" "$GRAY"
echo ""
center "This installer will:" "$WHITE"
echo "  ${GRAY}•${NC} Wipe selected disk and create encrypted LVM"
echo "  ${GRAY}•${NC} Install minimal Arch with security hardening"
echo "  ${GRAY}•${NC} Configure persistent /data partition"
echo ""
read -p "Press ENTER to continue or Ctrl+C to abort..."

# --- 1. INITIALIZATION ---
box "1" "INITIALIZATION" "$CYAN"

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i '/ParallelDownloads/a ILoveCandy' /etc/pacman.conf

umount -R /mnt 2>/dev/null || true
vgchange -an 2>/dev/null || true
cryptsetup close cryptlvm 2>/dev/null || true
swapoff -a 2>/dev/null || true

VG_NAME="vg0"

run_task "Checking Internet Connection" "ping -c 1 -W 3 google.com"
run_task "Initializing Pacman Keys" "pacman-key --init && pacman-key --populate archlinux"
run_task "Syncing Package Databases" "pacman -Sy"

# ==============================================================================
# PHASE 2: CONFIGURATION WIZARD (ALL USER INPUT)
# ==============================================================================
box "2" "CONFIGURATION WIZARD" "$MAGENTA"

# --- DISK SELECTION ---
echo ""
center "Available Disks:" "$YELLOW"
mapfile -t DISK_LIST < <(lsblk -d -n -o NAME,SIZE,MODEL,TYPE -e 7,11)
if [ ${#DISK_LIST[@]} -eq 0 ]; then
    echo "${RED}No disks found!${NC}"
    exit 1
fi

i=1
for disk in "${DISK_LIST[@]}"; do
    printf "   ${CYAN}[$i]${NC} /dev/$disk\n"
    ((i++))
done
echo ""

while true; do
    read -p "Select disk number (1-${#DISK_LIST[@]}): " DISK_NUM
    if validate_number "$DISK_NUM" 1 "${#DISK_LIST[@]}" 2>/dev/null; then
        SELECTED_LINE="${DISK_LIST[$((DISK_NUM-1))]}"
        DISK_NAME=$(echo "$SELECTED_LINE" | awk '{print $1}')
        DISK="/dev/$DISK_NAME"
        DISK_SIZE=$(lsblk -dn -o SIZE "$DISK")
        break
    fi
done

echo ""
center "Selected: $DISK ($DISK_SIZE)" "$GREEN"
sleep 1

# --- HOSTNAME ---
box "2" "CONFIGURATION WIZARD - System Identity" "$MAGENTA"
while true; do
    echo ""
    center "Enter Hostname (e.g., 'archlinux', 'workstation'):" "$WHITE"
    read -p "  > " HOSTNAME
    validate_hostname "$HOSTNAME" && break
done

# --- USERNAME ---
while true; do
    echo ""
    center "Enter Username (lowercase, e.g., 'alice'):" "$WHITE"
    read -p "  > " USERNAME
    validate_username "$USERNAME" && break
done

# --- ROOT PASSWORD ---
box "2" "CONFIGURATION WIZARD - Security" "$MAGENTA"
while true; do
    echo ""
    center "Set ROOT Password (min 12 chars, mixed case + numbers):" "$YELLOW"
    read -s -p "  Password: " ROOT_PASS
    echo ""
    if validate_password_strength "$ROOT_PASS"; then
        read -s -p "  Confirm:  " ROOT_PASS2
        echo ""
        if [ "$ROOT_PASS" == "$ROOT_PASS2" ]; then
            echo "${GREEN}✓ Root password set${NC}"
            break
        else
            echo "${RED}✗ Passwords don't match${NC}"
        fi
    fi
done

# --- USER PASSWORD ---
while true; do
    echo ""
    center "Set USER Password for '$USERNAME':" "$YELLOW"
    read -s -p "  Password: " USER_PASS
    echo ""
    if validate_password_strength "$USER_PASS"; then
        read -s -p "  Confirm:  " USER_PASS2
        echo ""
        if [ "$USER_PASS" == "$USER_PASS2" ]; then
            echo "${GREEN}✓ User password set${NC}"
            break
        else
            echo "${RED}✗ Passwords don't match${NC}"
        fi
    fi
done

# --- PARTITION SIZES ---
box "2" "CONFIGURATION WIZARD - Partitioning" "$MAGENTA"
echo ""
center "Disk Capacity: $DISK_SIZE" "$GRAY"
echo ""

while true; do
    read -p "SWAP size in GB (recommended: 8-16): " SWAP_NUM
    validate_number "$SWAP_NUM" 1 128 && break
done

while true; do
    read -p "ROOT size in GB (recommended: 60-100): " ROOT_NUM
    if validate_number "$ROOT_NUM" 20 500; then
        if [ "$ROOT_NUM" -lt 60 ]; then
            echo "${YELLOW}⚠ Warning: <60GB may be tight with updates${NC}"
            read -p "Continue? (y/n): " cont
            [[ "$cont" == "y" ]] && break
        else
            break
        fi
    fi
done

# --- VM DETECTION ---
echo ""
read -p "Is this a VM environment? (y/n): " IS_VM

# --- LUKS PASSWORD ---
box "2" "CONFIGURATION WIZARD - Disk Encryption" "$YELLOW"
echo ""
center "Set DISK ENCRYPTION Password (LUKS2):" "$RED"
center "⚠ This encrypts your entire system - DO NOT FORGET!" "$YELLOW"
echo ""
while true; do
    read -s -p "  Password: " LUKS_PASS
    echo ""
    if validate_password_strength "$LUKS_PASS"; then
        read -s -p "  Confirm:  " LUKS_PASS2
        echo ""
        if [ "$LUKS_PASS" == "$LUKS_PASS2" ]; then
            echo "${GREEN}✓ Encryption password set${NC}"
            break
        else
            echo "${RED}✗ Passwords don't match${NC}"
        fi
    fi
done

# ==============================================================================
# PHASE 3: CONFIRMATION SCREEN
# ==============================================================================
box "3" "INSTALLATION PLAN - FINAL CONFIRMATION" "$YELLOW"
echo ""
center "${RED}⚠ WARNING: ALL DATA ON $DISK WILL BE DESTROYED ⚠${NC}" "$RED"
echo ""
summary_item "Target Disk" "$DISK ($DISK_SIZE)"
summary_item "Hostname" "$HOSTNAME"
summary_item "Username" "$USERNAME"
summary_item "Partition Layout" "Boot:512M | Root:${ROOT_NUM}G | Swap:${SWAP_NUM}G | Data:Rest"
summary_item "System Type" "$([ "$IS_VM" == "y" ] && echo "Virtual Machine" || echo "Bare Metal (AMD)")"
summary_item "Encryption" "LUKS2 (Full Disk)"
summary_item "Data Vault" "/data (persistent, noexec)"
summary_item "Security" "AppArmor + UFW + DNS-over-TLS"
echo ""
line
echo ""
center "${BOLD}${RED}Type 'YES' (all caps) to proceed with installation:${NC}" "$RED"
read -p "  > " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo ""
    center "Installation aborted by user." "$GRAY"
    exit 0
fi

# ==============================================================================
# PHASE 4: DISK PARTITIONING
# ==============================================================================
box "4" "DISK PREPARATION" "$RED"

run_task "Wiping Disk" "wipefs --all --force $DISK && dd if=/dev/zero of=$DISK bs=1M count=100 status=none"
run_task "Creating GPT Partition Table" "sgdisk -Z $DISK"
run_task "Creating EFI Partition (512M)" "sgdisk -n 1:0:+512M -t 1:ef00 -c 1:'EFI System' $DISK"
run_task "Creating LVM Partition (Rest)" "sgdisk -n 2:0:0 -t 2:8e00 -c 2:'Linux LVM' $DISK"
run_task "Syncing Kernel" "partprobe $DISK && udevadm settle"

if [[ $DISK == *"nvme"* ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

echo ""
center "Partitions created: $PART1 (EFI), $PART2 (LUKS)" "$GREEN"

# --- LUKS ENCRYPTION ---
box "4" "DISK ENCRYPTION" "$RED"
echo ""
center "Encrypting partition $PART2 with LUKS2..." "$YELLOW"
echo "$LUKS_PASS" | cryptsetup luksFormat -q --type luks2 $PART2 -
echo "$LUKS_PASS" | cryptsetup open $PART2 cryptlvm -
echo ""
echo "${GREEN}✓ Encryption container opened${NC}"

# ==============================================================================
# PHASE 5: LVM SETUP & BACKGROUND DOWNLOADS
# ==============================================================================
box "5" "VOLUME MANAGEMENT & PARALLEL DOWNLOADS" "$BLUE"

run_task "Creating Physical Volume" "pvcreate /dev/mapper/cryptlvm"
run_task "Creating Volume Group ($VG_NAME)" "vgcreate $VG_NAME /dev/mapper/cryptlvm"
run_task "Creating Swap (${SWAP_NUM}G)" "lvcreate -L ${SWAP_NUM}G -n swap $VG_NAME"
run_task "Creating Root (${ROOT_NUM}G)" "lvcreate -L ${ROOT_NUM}G -n root $VG_NAME"
run_task "Creating Data (Remaining)" "lvcreate -l 100%FREE -n data $VG_NAME"
run_task "Activating Volumes" "udevadm settle && vgchange -ay $VG_NAME"

# --- PARALLEL PACKAGE PRE-DOWNLOAD ---
echo ""
center "Starting parallel package download..." "$CYAN"

if [[ "$IS_VM" == "y" ]]; then
    PACKAGES="base base-devel linux linux-headers linux-firmware lvm2 grub efibootmgr networkmanager git sudo man-db ufw zsh zsh-autosuggestions zsh-syntax-highlighting neovim ripgrep fd npm docker apparmor polkit"
else
    PACKAGES="base base-devel linux linux-headers linux-firmware lvm2 grub efibootmgr networkmanager git sudo man-db ufw zsh zsh-autosuggestions zsh-syntax-highlighting neovim ripgrep fd npm docker apparmor polkit amd-ucode mesa vulkan-radeon libva-mesa-driver"
fi

run_task "Downloading Packages to Cache" "pacman -Sw --noconfirm $PACKAGES" &
DOWNLOAD_PID=$!

# ==============================================================================
# PHASE 6: FORMATTING
# ==============================================================================
box "6" "FILESYSTEM CREATION" "$BLUE"

run_task "Formatting Boot (FAT32)" "mkfs.fat -F32 $PART1"
run_task "Formatting Root (EXT4)" "mkfs.ext4 -F /dev/mapper/$VG_NAME-root"
run_task "Formatting Data (EXT4)" "mkfs.ext4 -F /dev/mapper/$VG_NAME-data"
run_task "Formatting Swap" "mkswap /dev/mapper/$VG_NAME-swap"

run_task "Mounting Root" "mount /dev/mapper/$VG_NAME-root /mnt"
run_task "Mounting Boot" "mkdir -p /mnt/boot && mount $PART1 /mnt/boot"
run_task "Activating Swap" "swapon /dev/mapper/$VG_NAME-swap"
run_task "Mounting Data (noexec)" "mkdir -p /mnt/data && mount -o noexec /dev/mapper/$VG_NAME-data /mnt/data"

# Wait for package downloads to complete
echo ""
if kill -0 $DOWNLOAD_PID 2>/dev/null; then
    printf "  ${WHITE}Waiting for package downloads...${NC}"
    while kill -0 $DOWNLOAD_PID 2>/dev/null; do
        printf "."
        sleep 1
    done
    wait $DOWNLOAD_PID
    echo " ${GREEN}✓${NC}"
else
    echo "${GREEN}✓ Packages already downloaded${NC}"
fi

# ==============================================================================
# PHASE 7: SYSTEM INSTALLATION
# ==============================================================================
box "7" "SYSTEM INSTALLATION" "$GREEN"

# Start LazyVim clone in background
git clone --quiet https://github.com/LazyVim/starter /tmp/lazyvim >> "$LOG" 2>&1 &
LAZYVIM_PID=$!

run_task_cinema "Installing Base System" "pacstrap /mnt $PACKAGES"

run_task "Generating fstab" "genfstab -U /mnt >> /mnt/etc/fstab"

# ==============================================================================
# PHASE 8: SYSTEM CONFIGURATION
# ==============================================================================
box "8" "SYSTEM CONFIGURATION" "$MAGENTA"

if [[ "$IS_VM" == "y" ]]; then
    MODULES_CONFIG="MODULES=(virtio virtio_blk virtio_pci virtio_gpu)"
else
    MODULES_CONFIG="MODULES=(amdgpu)"
fi

# Wait for LazyVim clone
if kill -0 $LAZYVIM_PID 2>/dev/null; then
    wait $LAZYVIM_PID 2>/dev/null || true
fi

# --- GENERATE CHROOT CONFIG SCRIPT ---
cat <<EO_CONFIG > /mnt/setup_internal.sh
#!/bin/bash
set -e

# Optimize Pacman
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i '/ParallelDownloads/a ILoveCandy' /etc/pacman.conf

# Locale & Time
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc
echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen
locale-gen >/dev/null
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

# Initramfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
sed -i "s/^MODULES=.*/$MODULES_CONFIG/" /etc/mkinitcpio.conf
mkinitcpio -P >/dev/null 2>&1

# User & Shell
useradd -m -G wheel,video,audio,storage,docker -s /usr/bin/zsh $USERNAME
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Set Passwords (from config)
echo "root:${ROOT_PASS}" | chpasswd
echo "${USERNAME}:${USER_PASS}" | chpasswd

# --- ZSH CONFIGURATION ---
cat <<'EOZSH' > /home/$USERNAME/.zshrc
# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Minimalist Prompt
PROMPT="[%n@%m] %~ > "

# History
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt autocd
bindkey -v
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
EOZSH
chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

# Security Hardening
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns_over_tls.conf <<EODNS
[Resolve]
DNS=9.9.9.9 149.112.112.112
DNSOverTLS=yes
EODNS

# Kernel Hardening
cat > /etc/sysctl.d/50-security.conf <<EOSYSCTL
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
EOSYSCTL

# UFW Configuration
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw logging on >/dev/null 2>&1

# Data Vault Setup
mkdir -p /data/{Dokumente,Downloads,Bilder,Videos,Projects}
chown -R $USERNAME:$USERNAME /data

# Symlink User Directories to /data
for dir in Downloads Documents Pictures Videos; do
    rm -rf /home/$USERNAME/\$dir 2>/dev/null || true
done

ln -s /data/Downloads /home/$USERNAME/Downloads
ln -s /data/Dokumente /home/$USERNAME/Documents
ln -s /data/Bilder /home/$USERNAME/Pictures
ln -s /data/Videos /home/$USERNAME/Videos
ln -s /data/Projects /home/$USERNAME/Projects

chown -h $USERNAME:$USERNAME /home/$USERNAME/{Downloads,Documents,Pictures,Videos,Projects}

# LazyVim Setup
if [ -d /tmp/lazyvim ]; then
    mkdir -p /home/$USERNAME/.config
    cp -r /tmp/lazyvim /home/$USERNAME/.config/nvim
    rm -rf /home/$USERNAME/.config/nvim/.git
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
fi

# Bootloader
UUID=\$(blkid -s UUID -o value $PART2)
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=\$UUID:cryptlvm root=/dev/$VG_NAME/root apparmor=1 security=apparmor lsm=landlock,lockdown,yama,integrity,apparmor,bpf\"|" /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >/dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1

# Enable Services
systemctl enable NetworkManager >/dev/null 2>&1
systemctl enable apparmor >/dev/null 2>&1
systemctl enable ufw >/dev/null 2>&1
systemctl enable docker >/dev/null 2>&1
systemctl enable systemd-resolved >/dev/null 2>&1
EO_CONFIG

chmod +x /mnt/setup_internal.sh

# Copy LazyVim to chroot if available
if [ -d /tmp/lazyvim ]; then
    mkdir -p /mnt/tmp
    cp -r /tmp/lazyvim /mnt/tmp/ 2>/dev/null || true
fi

run_task "Applying System Configuration" "arch-chroot /mnt /setup_internal.sh"

# Cleanup
rm -f /mnt/setup_internal.sh
rm -rf /mnt/tmp/lazyvim
rm -rf /tmp/lazyvim

# ==============================================================================
# PHASE 9: COMPLETION
# ==============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

box "9" "INSTALLATION SUCCESSFUL" "$GREEN"
echo ""
center "🎉 Your Arch Sovereign system is ready! 🎉" "$GREEN"
echo ""
summary_item "Hostname" "$HOSTNAME"
summary_item "User" "$USERNAME (ZSH)"
summary_item "Kernel" "Latest Arch Linux"
summary_item "Disk" "$DISK ($DISK_SIZE)"
summary_item "Storage" "Root: ${ROOT_NUM}G | Swap: ${SWAP_NUM}G | Data: Rest"
summary_item "Encryption" "LUKS2 (Full Disk)"
summary_item "Security" "UFW + AppArmor + DoT + Hardened Kernel"
summary_item "Shell" "ZSH with plugins"
summary_item "Editor" "Neovim (LazyVim)"
summary_item "Interface" "Pure TTY (No DM)"
summary_item "Time Taken" "$((DURATION / 60))m $((DURATION % 60))s"
echo ""
line
echo ""
center "Next Steps:" "$CYAN"
echo "  ${GRAY}1.${NC} Reboot: ${WHITE}reboot${NC}"
echo "  ${GRAY}2.${NC} Login as: ${WHITE}$USERNAME${NC}"
echo "  ${GRAY}3.${NC} Optional: Install Hyprland for GUI"
echo ""
center "System is transient. Data is eternal." "$GRAY"
echo ""
