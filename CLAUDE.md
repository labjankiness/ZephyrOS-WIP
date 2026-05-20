# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

An Arch-based Linux distro with Wayfire Wayland compositor, UEFI Secure Boot, and 5 editions each bundling a different local Ollama model. Built requires an Arch Linux host.

## Build Commands

```bash
# Build a specific edition ISO (requires Arch Linux host)
cd build && ./build-edition.sh scholar   # or: dev, soc, lite, core

# Build the original single ISO (no editions)
cd build && ./build-iso.sh

# Test in QEMU/OVMF VM
cd vm && ./run-vm.sh

# Test Secure Boot specifically
cd vm && ./test-secureboot.sh

# Apply theme inside a running guest
cd theme && ./apply-theme.sh --dark   # or --light
```

## Secure Boot Workflow

```bash
cd secureboot
./gen-dev-keys.sh          # generate development MOK keys (one-time)
./sign-kernel.sh           # sign the kernel with MOK keys
./sign-module.sh <module>  # sign out-of-tree kernel modules
./enroll-mok.sh            # enroll keys in UEFI firmware
```

Keys live in `secureboot/keys/` — never commit the private keys.

## Architecture

Boot chain: `UEFI → shimx64.efi (MS-signed) → GRUB2 → signed kernel → Wayfire`

**Edition system:** `editions/base/` holds shared packages, the first-boot service, and the `zephyros-ai` wrapper script. Each edition subfolder (`scholar/`, `dev/`, `soc/`, `lite/`) is an overlay that adds packages and sets the Ollama model. `build-edition.sh` merges base + edition overlay into an archiso profile before building.

**Dotfiles** in `dotfiles/` are installed into the ISO's skeleton (`/etc/skel`) so every new user gets them. Wayfire config is in `dotfiles/wayfire/`, launcher in `dotfiles/wofi/`.

**AI integration:** Each edition pulls its Ollama model on first boot via a systemd service in `editions/base/`. The `zephyros-ai` CLI wrapper is a shell script in the base edition.

## Edition → Model Mapping

| Edition | Model | Min RAM |
|---------|-------|---------|
| scholar | phi3:mini | 8 GB |
| dev | deepseek-coder-v2:16b-lite | 16 GB |
| soc | llama3.1:8b | 16 GB |
| lite | smollm2:1.7b | 4 GB |
| core | none | 4 GB |

## VM Config

`vm/vm.env` holds QEMU/OVMF paths. Edit this file to point at your OVMF firmware before running `run-vm.sh`.
