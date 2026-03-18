# ZephyrOS Roadmap

This roadmap is organized into major phases.

## Phase 1 — VM-stable with Secure Boot [Complete]

Goal: a reproducible ZephyrOS ISO that boots reliably in VMs with Secure Boot,
showcasing the core Wayfire desktop.

Milestones:

- ISO build:
  - Arch-based `archiso` profile under `build/`.
  - Single-command build via `build/build-iso.sh`.
- Boot and Secure Boot:
  - UEFI-only boot via shim → GRUB2 → signed kernel.
  - Development MOK workflow documented and scripted under `secureboot/`.
  - `vm/test-secureboot.sh` validates Secure Boot state inside the guest.
- Desktop:
  - Wayfire compositor with a Windows 11-inspired shell (centered taskbar,
    frosted launcher, rounded corners).
  - Minimal app set (Thunar, Kitty, Wofi, browser/editor TBD).
- Tooling:
  - QEMU/KVM + OVMF launch script (`vm/run-vm.sh`) and defaults (`vm.env`).
  - Theming/dotfiles pipeline via `theme/apply-theme.sh`.

## Phase 1.5 — Edition System with AI Integration [Complete]

Goal: multiple ZephyrOS editions, each bundled with an AI model via Ollama.

Milestones:

- Edition system:
  - Base + edition overlay architecture under `editions/`.
  - `build/build-edition.sh` merges packages and builds per-edition ISOs.
  - 5 editions: Core, Scholar, Dev, SOC, Lite.
- AI integration:
  - Ollama bundled in base packages.
  - First-boot systemd service auto-pulls the edition's AI model.
  - `zephyros-ai` wrapper with edition-specific system prompts.
- Edition-specific packages and MOTDs for each edition.

## Phase 2 — Full Installer Experience [Complete]

Goal: download ISO → boot VM/bare metal → install → reboot → use ZephyrOS.

Milestones:

- TUI installer (`zephyros-install`):
  - Dialog-based guided installation with disk selection, partitioning,
    user account creation, timezone, and bootloader setup.
  - GPT partitioning with EFI (512MB) + root (ext4).
  - GRUB bootloader installation for UEFI.
  - Copies edition config, AI wrapper, first-boot service, and dotfiles.
  - Auto-login + Wayfire auto-start on installed system.
- Live session experience:
  - Welcome dialog on boot with Install / Try / Terminal options.
  - "Install ZephyrOS" desktop shortcut and application entry.
  - Package list bundled in ISO for offline-capable installation.
- Merged package list included in ISO so pacstrap can install the full
  edition package set during installation.

## Phase 3 — Bare metal testing + hardware compatibility

Goal: ZephyrOS runs well on a range of real hardware.

Milestones:

- Hardware coverage:
  - GPUs: Intel, AMD, and at least one Nvidia path documented.
  - Wi-Fi/Bluetooth: verify common chipsets, document any non-free firmware.
- Power and performance:
  - Suspend/resume and basic power management on laptops.
  - Boot-time analysis with `systemd-analyze` and service tuning.
- Telemetry stance:
  - Confirm that no telemetry or tracking packages are shipped by default.

## Phase 4 — Public ISO release

Goal: polished ZephyrOS ISO with public documentation and a clear Secure Boot
story.

Milestones:

- Release process:
  - Versioned ISOs with checksums and signatures.
  - Public changelog and upgrade guidance.
- Secure Boot hardening:
  - Shim submitted and, if accepted, signed by the Microsoft UEFI CA.
  - Finalized key management and revocation policy.
- Documentation:
  - User guide for installation, updates, and basic customization.
  - Developer guide for rebuilding the ISO and contributing changes.
- Presentation:
  - Website or landing page describing ZephyrOS goals and download links.
