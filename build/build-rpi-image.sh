#!/usr/bin/env bash
#
# build-rpi-image.sh — Build a ZephyrOS aarch64 image for Raspberry Pi.
#
# Approach: Arch Linux ARM (ALARM) doesn't have archiso; the canonical way to
# produce an SD image is to extract the ALARM rootfs tarball, customize it via
# a qemu-user-static chroot, write it to a partitioned disk image, and ship
# the resulting .img.
#
# This script is the *cross-build* path — it runs on x86_64 (host or GitHub
# Actions ubuntu-latest) and produces a bootable .img for aarch64 Pi 3/4/5.
#
# Host requirements:
#   - Linux (Arch, Debian/Ubuntu both work)
#   - qemu-user-static (qemu-aarch64-static binary) + binfmt_misc registered
#   - sudo
#   - parted, dosfstools, e2fsprogs, kpartx (or losetup), wget, curl, tar,
#     gnupg, arch-install-scripts (for arch-chroot)
#
# Usage:
#   ./build-rpi-image.sh                     # default: Pi 4/5, 4 GiB image
#   ./build-rpi-image.sh --model pi4 --size 6
#   ./build-rpi-image.sh --edition core      # use core packages overlay
#
# Output:
#   build/out/zephyros-rpi-<model>-<date>.img

set -euo pipefail

# --- Defaults ---
MODEL="aarch64"           # aarch64 (Pi 3/4/5); armv7 deprecated
EDITION="core"            # which edition's portable assets to layer
SIZE_GB=4                 # output image size
ALARM_TARBALL_URL=""      # filled in below per model
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$SCRIPT_DIR/out"
WORK_DIR="$SCRIPT_DIR/work-rpi"

# --- Args ---
while [ "$#" -gt 0 ]; do
    case "$1" in
        --model)   MODEL="$2"; shift 2 ;;
        --edition) EDITION="$2"; shift 2 ;;
        --size)    SIZE_GB="$2"; shift 2 ;;
        -h|--help)
            sed -n '3,28p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

case "$MODEL" in
    aarch64|pi4|pi5|pi3)
        ALARM_TARBALL_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
        ;;
    *)
        echo "Unsupported model: $MODEL (use aarch64/pi3/pi4/pi5)" >&2
        exit 2
        ;;
esac

log() { printf '[rpi-build] %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Host preflight ---
[ "$(uname -s)" = "Linux" ] || die "This script needs Linux."
[ "$(id -u)" -eq 0 ] || die "Run with sudo (we need losetup, mount, chroot)."

for cmd in qemu-aarch64-static parted mkfs.fat mkfs.ext4 losetup wget tar arch-chroot; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing: $cmd"
done

# binfmt_misc handler for aarch64 must already be registered. On Ubuntu/Debian
# this comes from `qemu-user-static`; on Arch from `qemu-user-static-binfmt`.
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    die "binfmt_misc qemu-aarch64 handler not registered.\nOn Debian/Ubuntu: apt install qemu-user-static binfmt-support\nOn Arch:         pacman -S qemu-user-static-binfmt && systemctl restart systemd-binfmt"
fi

mkdir -p "$OUT_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

IMG="$OUT_DIR/zephyros-rpi-${MODEL}-$(date +%Y.%m.%d).img"
TARBALL="$WORK_DIR/alarm-rootfs.tar.gz"
ROOTFS="$WORK_DIR/rootfs"
mkdir -p "$ROOTFS"

# --- Step 1: download Arch Linux ARM tarball ---
log "Downloading ALARM aarch64 rootfs ($ALARM_TARBALL_URL)"
wget --progress=dot:giga -O "$TARBALL" "$ALARM_TARBALL_URL"
# Verify size (ALARM doesn't publish a stable per-build signature)
TSIZE=$(stat -c '%s' "$TARBALL")
[ "$TSIZE" -gt $((300*1024*1024)) ] || die "Tarball suspiciously small ($TSIZE bytes); aborting."

# --- Step 2: create blank image + partitions ---
log "Creating ${SIZE_GB} GiB image at $IMG"
truncate -s "${SIZE_GB}G" "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary fat32 1MiB 257MiB
parted -s "$IMG" mkpart primary ext4 257MiB 100%
parted -s "$IMG" set 1 boot on

LOOP=$(losetup --find --show --partscan "$IMG")
log "Loop device: $LOOP"
trap 'set +e; umount -R "$ROOTFS/boot" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null; exit' EXIT INT TERM

mkfs.fat -F32 -n "BOOT"     "${LOOP}p1"
mkfs.ext4 -L "ZephyrOS-RPI" "${LOOP}p2"

# --- Step 3: extract ALARM rootfs ---
log "Mounting and extracting rootfs"
mount "${LOOP}p2" "$ROOTFS"
mkdir -p "$ROOTFS/boot"
mount "${LOOP}p1" "$ROOTFS/boot"

# bsdtar preserves ACLs/xattrs which ALARM relies on; fall back to tar.
if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xpf "$TARBALL" -C "$ROOTFS"
else
    tar --acls --xattrs -xpf "$TARBALL" -C "$ROOTFS"
fi
sync

# --- Step 4: register qemu inside the chroot ---
cp /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/"
mount --bind /dev  "$ROOTFS/dev"
mount --bind /proc "$ROOTFS/proc"
mount --bind /sys  "$ROOTFS/sys"

# --- Step 5: customize the rootfs (chroot) ---
log "Customizing in chroot..."

# Initialize pacman keyring inside the chroot
arch-chroot "$ROOTFS" /bin/bash -e <<'CHROOT_KEYS'
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Sy --noconfirm
CHROOT_KEYS

# Install the curated ZephyrOS-on-ARM package subset. We can't ship every
# x86_64 package — some have no aarch64 build, some require an AUR rebuild
# that's slow under emulation. The set below is the minimum viable Wayfire
# desktop + AI runtime.
log "Installing ZephyrOS-on-ARM package subset"
arch-chroot "$ROOTFS" pacman -S --noconfirm --needed \
    base linux-rpi linux-firmware sudo \
    networkmanager network-manager-applet \
    wayland mesa labwc wofi xorg-server-xwayland \
    kitty zsh zsh-completions \
    pipewire pipewire-pulse wireplumber \
    thunar gvfs \
    inter-font noto-fonts noto-fonts-emoji \
    flatpak xdg-desktop-portal xdg-desktop-portal-wlr \
    nftables \
    git curl wget htop \
    || die "pacman install failed"

# Ollama is x86_64-only via official packaging at the moment; document
# the manual path inside the image. Don't fail the build over it.
cat > "$ROOTFS/etc/zephyros-ai-note" <<'AINOTE'
Ollama for aarch64 is not packaged in Arch Linux ARM yet. To install:

    curl -fsSL https://ollama.com/install.sh | sh

Then `zephyros-ai` will work as on x86 — pick a model appropriate for your
Pi's RAM (4GB Pi → smollm2:135m; 8GB Pi → phi3:mini; 16GB Pi 5 → llama3:8b).
AINOTE

# --- Step 6: layer ZephyrOS portable assets ---
log "Layering ZephyrOS configs and scripts"

# Edition config and AI wrapper (the AI wrapper is portable; it just calls
# `ollama run`, which exists once the user installs it on aarch64).
install -m 0644 "$ROOT_DIR/editions/$EDITION/edition.conf" "$ROOTFS/etc/zephyros-edition.conf"
install -m 0755 "$ROOT_DIR/editions/base/airootfs/usr/local/bin/zephyros-ai"             "$ROOTFS/usr/local/bin/"
install -m 0755 "$ROOT_DIR/editions/base/airootfs/usr/local/bin/zephyros-hwreport"       "$ROOTFS/usr/local/bin/"
install -m 0755 "$ROOT_DIR/editions/base/airootfs/usr/local/bin/zephyros-bootreport"     "$ROOTFS/usr/local/bin/"
install -m 0755 "$ROOT_DIR/editions/base/airootfs/usr/local/bin/zephyros-telemetry-audit" "$ROOTFS/usr/local/bin/"
install -m 0644 "$ROOT_DIR/editions/base/airootfs/etc/nftables.conf"                     "$ROOTFS/etc/nftables.conf"

# Dotfiles -> /etc/skel so the default `alarm` user (and any new users) get them.
if [ -d "$ROOT_DIR/dotfiles" ]; then
    mkdir -p "$ROOTFS/etc/skel/.config"
    for d in wayfire kitty wofi wf-panel-pi; do
        [ -d "$ROOT_DIR/dotfiles/$d" ] && cp -a "$ROOT_DIR/dotfiles/$d" "$ROOTFS/etc/skel/.config/"
    done
    [ -f "$ROOT_DIR/dotfiles/zsh/.zshrc" ] && cp "$ROOT_DIR/dotfiles/zsh/.zshrc" "$ROOTFS/etc/skel/"
fi

# Enable our services in the target system
arch-chroot "$ROOTFS" /bin/bash -e <<'CHROOT_SERVICES'
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable nftables
# ALARM ships an `alarm` user with password `alarm`. Replace with a
# zephyros user; document the credentials in the README that ships
# alongside the image.
useradd -m -G wheel,video,audio,input -s /bin/zsh zephyros 2>/dev/null || true
echo 'zephyros:zephyros' | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
# Default root password is also `root` on ALARM — change it.
echo 'root:zephyros-root' | chpasswd
CHROOT_SERVICES

# --- Step 7: clean up and unmount ---
log "Cleaning up chroot artifacts"
rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
arch-chroot "$ROOTFS" pacman -Scc --noconfirm >/dev/null 2>&1 || true

sync
umount -R "$ROOTFS/boot" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS" 2>/dev/null || true
losetup -d "$LOOP"
trap - EXIT INT TERM

log "Built: $IMG"
ls -lh "$IMG"

cat <<DONE

Image written to:
  $IMG

Write to an SD card (replace /dev/sdX with your card):
  sudo dd if=$IMG of=/dev/sdX bs=4M status=progress conv=fsync
  sync

Default credentials on first boot:
  user:  zephyros / zephyros        (in wheel, has sudo)
  root:  zephyros-root

Boot the Pi, log in, change passwords, then continue per HARDENING.md
or USER-GUIDE.md.
DONE
