# ZephyrOS Roadmap

This roadmap is organized into three major phases.

## Phase 1 — VM-stable with Secure Boot

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

## Phase 2 — Bare metal testing + hardware compatibility

Goal: ZephyrOS runs well on a range of real hardware.

Milestones:

- Hardware coverage:
  - GPUs: Intel, AMD, and at least one Nvidia path documented.
  - Wi-Fi/Bluetooth: verify common chipsets, document any non-free firmware.
- Power and performance:
  - Suspend/resume and basic power management on laptops.
  - Boot-time analysis with `systemd-analyze` and service tuning.
- Installer story:
  - Evaluate options for a minimal installer (Calamares or custom scripted
    flow), without bloating the ISO.
- Telemetry stance:
  - Confirm that no telemetry or tracking packages are shipped by default.

## Phase 3 — Public ISO release

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

