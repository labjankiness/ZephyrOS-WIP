#!/usr/bin/env bash
#
# ZephyrOS archiso profile definition
#
# This profile is intentionally minimal and tuned for:
# - UEFI-only boot
# - shim → GRUB2 → signed kernel Secure Boot chain (wired up by build hooks)
# - Wayfire-based graphical session as the primary target

iso_name="zephyros"
iso_label="ZEPHYROS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="ZephyrOS Project"
iso_application="ZephyrOS Live ISO (Wayland/Wayfire, Secure Boot-ready)"
iso_version="$(date --date=\"@${SOURCE_DATE_EPOCH:-$(date +%s)}\" +%Y.%m.%d)"

# Installation directory (max 8 chars, alphanumeric only)
install_dir="arch"

# Boot modes: UEFI-only, GRUB-based. We will rely on shim for Secure Boot,
# but shim and GRUB binaries are installed via packages and hooks.
bootmodes=('uefi-x64.grub.esp')

arch="x86_64"

pacman_conf="pacman.conf"

airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')

file_permissions=(
  # Example: ["path"]="0:0:755"
)

