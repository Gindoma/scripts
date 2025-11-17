#!/bin/bash
set -e
set -o pipefail

# ==============================================================================
#  ARCH LINUX INSTALLER V40 (Minimalist Prompt, Cinema Mode, Clean TTY)
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
    local title="$1"
    local color="$2"
    clear
    echo ""
    line
    center "$title" "$color"
    line
    echo ""
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
    )
    
    eval "$command" >> "$LOG" 2>&1 &
    local pid=$!
    
    local delay=0.1
    local quote_delay=0
    local spinstr='|/-\'
    local quote_index=0
    
    tput civis
    printf "  ${WHITE}%-30s${NC}" "$message"
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
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
        printf "\r  ${WHITE}%-30s${NC}" "$message"
    done
    
    tput cnorm
    wait $pid
    local exit_code=$?
    tput el 
    
    if [ $exit_code -eq 0 ]; then
        printf " [${GREEN}OK${NC}]\n"
    else
        printf " [${RED}FAIL${NC}]\n"
        echo -e "${RED}!!! ERROR DETECTED !!! Last lines of log:${NC}"
        tail -n 10 "$LOG"
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
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${CYAN}%c${NC}]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf " [${GREEN}OK${NC}]\n"
    else
        printf " [${RED}FAIL${NC}]\n"
        echo ""
        echo -e "${RED}!!! ERROR DETECTED !!! Check details below:${NC}"
        tail -n 10 "$LOG"
        exit 1
    fi
}

summary_item() {
    local key="$1"
    local val="$2"
    local dots="........................................"
    printf "   ${WHITE}%-16s ${GRAY}%s ${CYAN}%s${NC}\n" "$key" "${dots:0:$((20 - ${#key}))}" "$val"
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

# --- 1. INITIALIZATION ---
box "ARCH LINUX INSTALLER // INITIALIZATION" "$CYAN"

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i '/ParallelDownloads/a ILoveCandy' /etc/pacman.conf

umount -R /mnt 2>/dev/null || true
vgchange -an 2>/dev/null || true
cryptsetup close cryptlvm 2>/dev/null || true
swapoff -a 2>/dev/null || true

VG_NAME="vg0"

run_task "Checking Internet" "ping -c 1 google.com"
run_task "Init Pacman Keys" "pacman-key --init && pacman-key --populate archlinux"
run_task "Syncing Databases" "pacman -Sy"

# --- 2. DISK SELECTION ---
box "HARDWARE SELECTION" "$CYAN"
mapfile -t DISK_LIST < <(lsblk -d -n -o NAME,SIZE,MODEL,TYPE -e 7,11)
if [ ${#DISK_LIST[@]} -eq 0 ]; then echo "No disks!"; exit 1; fi

i=1
for disk in "${DISK_LIST[@]}"; do
    center "[$i] /dev/$disk" "$GRAY"
    ((i++))
done
echo ""

while true; do
    center "Select Target Disk (1-${#DISK_LIST[@]}):" "$MAGENTA"
    read -p "             > " DISK_NUM
    if [[ "$DISK_NUM" =~ ^[0-9]+$ ]] && [ "$DISK_NUM" -ge 1 ] && [ "$DISK_NUM" -le "${#DISK_LIST[@]}" ]; then
        SELECTED_LINE="${DISK_LIST[$((DISK_NUM-1))]}"
        DISK_NAME=$(echo "$SELECTED_LINE" | awk '{print $1}')
        DISK="/dev/$DISK_NAME"
        break
    fi
done

# --- 3. CONFIGURATION ---
box "SYSTEM CONFIGURATION" "$MAGENTA"

center "Enter Hostname:" "$WHITE"
read -p "             > " HOSTNAME
center "Enter Username:" "$WHITE"
read -p "             > " USERNAME

echo ""
center "Disk Capacity: $(lsblk -dn -o SIZE $DISK)" "$GRAY"
center "Enter SWAP Size (GB) [e.g. 8]:" "$WHITE"
read -p "             > " SWAP_NUM
center "Enter ROOT Size (GB) [e.g. 40]:" "$WHITE"
read -p "             > " ROOT_NUM
center "Is this a VM? (y/n):" "$WHITE"
read -p "             > " IS_VM

# --- 4. PARTITIONING ---
box "PARTITIONING & SECURITY" "$RED"
center "!!! WARNING: WIPING $DISK !!!" "$RED"
sleep 2

run_task "Wiping Disk" "wipefs --all --force $DISK && dd if=/dev/zero of=$DISK bs=1M count=100 status=none"
run_task "Partitioning (GPT)" "sgdisk -Z $DISK && sgdisk -n 1:0:+512M -t 1:ef00 -c 1:'EFI System' $DISK && sgdisk -n 2:0:0 -t 2:8e00 -c 2:'Linux LVM' $DISK"
run_task "Syncing Kernel" "partprobe $DISK && udevadm settle"

if [[ $DISK == *"nvme"* ]]; then PART1="${DISK}p1"; PART2="${DISK}p2"; else PART1="${DISK}1"; PART2="${DISK}2"; fi

echo ""
center ">> ENCRYPTION SETUP <<" "$YELLOW"
center "Enter Password:" "$GRAY"
cryptsetup luksFormat -q $PART2
echo ""
center "Verify Password:" "$GRAY"
cryptsetup open $PART2 cryptlvm

# --- 5. LVM SETUP ---
box "VOLUME MANAGEMENT" "$BLUE"
run_task "Creating Physical Volume" "pvcreate /dev/mapper/cryptlvm"
run_task "Creating Group ($VG_NAME)" "vgcreate $VG_NAME /dev/mapper/cryptlvm"
run_task "Creating Swap (${SWAP_NUM}G)" "lvcreate -L ${SWAP_NUM}G -n swap $VG_NAME"
run_task "Creating Root (${ROOT_NUM}G)" "lvcreate -L ${ROOT_NUM}G -n root $VG_NAME"
run_task "Creating Data (Rest)" "lvcreate -l 100%FREE -n data $VG_NAME"
run_task "Activating" "udevadm settle && vgchange -ay $VG_NAME"

# --- 6. FORMATTING ---
box "FORMATTING" "$BLUE"
run_task "Formatting Boot" "mkfs.fat -F32 $PART1"
run_task "Formatting Root" "mkfs.ext4 -F /dev/mapper/$VG_NAME-root"
run_task "Formatting Data" "mkfs.ext4 -F /dev/mapper/$VG_NAME-data"
run_task "Formatting Swap" "mkswap /dev/mapper/$VG_NAME-swap"

run_task "Mounting Root" "mount /dev/mapper/$VG_NAME-root /mnt"
run_task "Mounting Boot" "mkdir -p /mnt/boot && mount $PART1 /mnt/boot"
run_task "Mounting Swap" "swapon /dev/mapper/$VG_NAME-swap"
run_task "Mounting Data" "mkdir -p /mnt/data && mount -o noexec /dev/mapper/$VG_NAME-data /mnt/data"

# --- 7. INSTALLATION ---
box "SYSTEM INSTALLATION" "$GREEN"
# CINEMA MODE
run_task_cinema "Downloading & Installing Packages" "pacstrap /mnt base base-devel linux linux-headers linux-firmware lvm2 grub efibootmgr networkmanager git sudo man-db ufw zsh zsh-autosuggestions zsh-syntax-highlighting neovim ripgrep fd npm docker apparmor polkit amd-ucode mesa vulkan-radeon libva-mesa-driver"

run_task "Generating fstab" "genfstab -U /mnt >> /mnt/etc/fstab"

# --- 8. INTERNAL CONFIGURATION ---
box "SYSTEM CONFIGURATION" "$MAGENTA"

if [[ "$IS_VM" == "y" ]]; then
    MODULES_CONFIG="MODULES=(virtio virtio_blk virtio_pci virtio_gpu)"
else
    MODULES_CONFIG="MODULES=(amdgpu)" 
fi

# --- GENERATE CONFIG SCRIPT ---
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

# --- ZSH CONFIGURATION (CLEAN & SIMPLE) ---
cat <<'EOZSH' > /home/$USERNAME/.zshrc
# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Minimalist Prompt (No Colors, just Text)
# Format: [user@host] ~/current/dir >
PROMPT="[%n@%m] %~ > "

# History
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt autocd
bindkey -v
alias ll='ls -la'
EOZSH
chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

# Security
mkdir -p /etc/systemd/resolved.conf.d
echo "[Resolve]" > /etc/systemd/resolved.conf.d/dns_over_tls.conf
echo "DNS=9.9.9.9 149.112.112.112" >> /etc/systemd/resolved.conf.d/dns_over_tls.conf
echo "DNSOverTLS=yes" >> /etc/systemd/resolved.conf.d/dns_over_tls.conf
echo "kernel.dmesg_restrict = 1" > /etc/sysctl.d/50-dmesg-restrict.conf
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Flatpak
flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo || true

# Data
mkdir -p /data/Dokumente /data/Downloads /data/Bilder /data/Videos /data/Projects
chown -R $USERNAME:$USERNAME /data
rm -rf /home/$USERNAME/Downloads && ln -s /data/Downloads /home/$USERNAME/Downloads
rm -rf /home/$USERNAME/Documents && ln -s /data/Dokumente /home/$USERNAME/Documents
rm -rf /home/$USERNAME/Pictures  && ln -s /data/Bilder    /home/$USERNAME/Pictures
rm -rf /home/$USERNAME/Videos    && ln -s /data/Videos    /home/$USERNAME/Videos
ln -s /data/Projects /home/$USERNAME/Projects
chown -h $USERNAME:$USERNAME /home/$USERNAME/Downloads /home/$USERNAME/Documents /home/$USERNAME/Pictures /home/$USERNAME/Videos /home/$USERNAME/Projects

# LazyVim
sudo -u $USERNAME mkdir -p /home/$USERNAME/.config
sudo -u $USERNAME git clone https://github.com/LazyVim/starter /home/$USERNAME/.config/nvim >/dev/null 2>&1
rm -rf /home/$USERNAME/.config/nvim/.git

# Bootloader
UUID=\$(cryptsetup luksUUID $PART2)
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=\$UUID:$VG_NAME root=/dev/$VG_NAME/root apparmor=1 security=apparmor lsm=landlock,lockdown,yama,integrity,apparmor,bpf\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >/dev/null 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1

# Services
systemctl enable NetworkManager
systemctl enable apparmor
systemctl enable ufw
systemctl enable docker
systemctl enable systemd-resolved
EO_CONFIG

chmod +x /mnt/setup_internal.sh
run_task "Applying System Configuration" "arch-chroot /mnt /setup_internal.sh"
rm /mnt/setup_internal.sh

# --- 9. PASSWORDS ---
box "SECURITY CREDENTIALS" "$YELLOW"
center "Set ROOT Password:" "$WHITE"
arch-chroot /mnt passwd
echo ""
center "Set USER Password ($USERNAME):" "$WHITE"
arch-chroot /mnt passwd $USERNAME

# --- SUMMARY ---
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

box "INSTALLATION SUCCESSFUL" "$GREEN"
echo ""
summary_item "Hostname" "$HOSTNAME"
summary_item "User" "$USERNAME (ZSH)"
summary_item "Kernel" "Standard Linux"
summary_item "Disk" "$DISK"
summary_item "Storage" "Root: ${ROOT_NUM}G | Swap: ${SWAP_NUM}G"
summary_item "Security" "UFW + AppArmor + DoT"
summary_item "Interface" "Pure TTY (Console)"
summary_item "Time Taken" "$((DURATION / 60))m $((DURATION % 60))s"
echo ""
line
center "Reboot now. Login and enjoy your Clean Arch." "$CYAN"
echo ""
