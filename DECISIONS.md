# ZephyrOS Design Decisions

This document records major design choices and their rationale.

## 1. Base distro: Arch vs Debian

- **Choice**: Arch Linux
- **Alternatives**: Debian Stable, Ubuntu LTS
- **Rationale**:
  - Arch provides a **simple userspace and packaging model** with first-class
    support for `archiso`, making ISO builds scriptable and reproducible.
  - Faster access to **up-to-date Wayland/Wayfire stacks** and GPU drivers.
  - The rolling model fits an experimental desktop OS better than a frozen LTS.

## 2. Desktop stack: Wayfire vs KDE Plasma

- **Choice**: Wayfire-based Wayland compositor
- **Alternatives**: KDE Plasma (Wayland), GNOME Shell
- **Rationale**:
  - Wayfire is **lightweight and modular**, with plugins for blur, rounded
    corners, and animations that map well to the ZephyrOS visual goals.
  - Easier to keep the overall install footprint small than with a full Plasma
    or GNOME stack.
  - Compositor-level control over effects enables a **Windows 11-style shell**
    without shipping an entire heavyweight DE.

## 3. File manager: Thunar vs Dolphin

- **Choice**: Thunar
- **Alternatives**: Dolphin, Nautilus
- **Rationale**:
  - Thunar has a **small dependency footprint** and integrates cleanly with a
    Wayland/Wayfire session.
  - Dolphin would pull in a **large portion of the KDE stack**, increasing ISO
    size and memory use.

## 4. Terminal: Kitty vs Alacritty

- **Choice**: Kitty
- **Alternatives**: Alacritty, GNOME Terminal, Konsole
- **Rationale**:
  - Kitty is **Wayland-friendly**, fast, and themable, with minimal
    dependencies.
  - Alacritty is also lightweight, but Kitty's feature set and configuration
    style align better with the desired polished desktop feel.

## 5. Boot chain: shim + GRUB2 vs alternatives

- **Choice**: shim → GRUB2 → signed Linux kernel
- **Alternatives**: systemd-boot, rEFInd, direct kernel boot
- **Rationale**:
  - The shim + GRUB2 chain is the **most widely deployed Secure Boot path** on
    Linux and well-understood by firmware vendors.
  - GRUB2 offers flexible menuing and multi-boot options for future phases.
  - Aligns with a future goal of **submitting shim to Microsoft’s UEFI CA** for
    public releases.

