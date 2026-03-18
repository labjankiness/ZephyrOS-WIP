# ZephyrOS ISO Build (`build/`)

This directory contains the **Arch-based `archiso` profile** and tooling to build the ZephyrOS ISO.

## Layout

- `archiso/profiledef.sh`  
  Archiso profile definition for a **UEFI-only**, **Wayfire-based** ZephyrOS live ISO.

- `archiso/packages.x86_64`  
  Minimal package set for the base system, boot stack (shim + GRUB2), Secure Boot tooling, and Wayfire desktop.

- `build-iso.sh`  
  POSIX shell script that wraps `mkarchiso` to produce a reproducible ZephyrOS ISO into `build/out/`.

## AUR packages and the local repo

ZephyrOS intentionally uses a small number of **AUR-only** packages for theming
and shim on vanilla Arch. Because `archiso` installs packages via `pacman`,
these AUR packages are **pre-built into a local pacman repo** before the ISO
build runs.

### What happens during `./build-iso.sh`

- `build/scripts/build-localrepo.sh`:
  - clones/updates PKGBUILDs from AUR
  - runs `makepkg` to build:
    - `adw-gtk3` (# AUR)
    - `fluent-icon-theme-git` (# AUR)
    - `archlinux-shim` (# AUR)
  - creates a local repo DB under `build/localrepo/` via `repo-add`
  - writes `build/archiso/airootfs/etc/pacman.d/local.conf` pointing to the
    build-host `file://.../build/localrepo` path

- `build/archiso/pacman.conf` includes `airootfs/etc/pacman.d/local.conf`
  **above** the standard Arch repos so `mkarchiso` can resolve these packages.

### Build host requirements

In addition to `archiso`, you need:

- `base-devel` (for `makepkg`)
- `git` (to fetch AUR PKGBUILDs)
- `pacman-contrib` (for `repo-add`)

## Requirements

Run this script on an **Arch or Arch-based host** with at least:

- `archiso`
- `sbsigntools`
- `efitools`
- `grub`
- shim (see `SECUREBOOT.md`, plus the local repo flow above)

## Usage

```sh
cd build
./build-iso.sh
```

The resulting ISO(s) will be written to `build/out/`.

