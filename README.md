# ZephyrOS

A minimal, modern Arch-based Linux distribution with a Wayfire Wayland compositor and UEFI Secure Boot support. Inspired by the Windows 11 aesthetic — centered taskbar, frosted launcher, clean animations — without the bloat.

## Status

**Phase 1 — VM-stable with Secure Boot** (current). See [ROADMAP.md](ROADMAP.md) for the full 3-phase plan.

## Architecture

```
UEFI Firmware → shimx64.efi (Microsoft-signed) → GRUB2 → signed Linux kernel
                                                           ↓
                                                    Wayfire compositor
                                                    wf-panel-pi taskbar
                                                    Wofi launcher
                                                    Kitty terminal + zsh
```

**Base:** Arch Linux (rolling release, archiso for reproducible ISOs)
**Display:** Wayfire — lightweight Wayland compositor with blur, rounded corners, animations
**Boot:** shim + GRUB2 Secure Boot chain with development MOK signing

## Key Design Decisions

- **Arch over Debian/Ubuntu** — Rolling model, first-class archiso support, modern Wayland stack
- **Wayfire over KDE Plasma** — Modular plugin-based effects without full DE bloat
- **Secure Boot from day one** — Development MOK workflow validates boot chain early
- **Thunar + Kitty** — Small footprint alternatives to Dolphin and GNOME Terminal

See [DECISIONS.md](DECISIONS.md) for full rationale.

## Quick Start

**Build the ISO** (requires Arch Linux host):
```bash
cd build && ./build-iso.sh
```

**Test in VM** (QEMU/KVM + OVMF):
```bash
cd vm && ./run-vm.sh
```

**Apply theme** (inside the guest):
```bash
cd theme && ./apply-theme.sh [--light|--dark]
```

**Validate Secure Boot** (inside the guest):
```bash
cd vm && ./test-secureboot.sh
```

## Project Structure

```
zephyros/
├── build/            # Archiso profile and ISO build scripts
├── dotfiles/         # Wayfire, Kitty, Wofi, zsh configs
├── secureboot/       # MOK key generation, kernel/module signing, enrollment
├── theme/            # Single-command theme application (dark/light)
├── vm/               # QEMU/OVMF launch and Secure Boot validation
├── DECISIONS.md      # Design decision rationale
├── ROADMAP.md        # 3-phase development plan
└── SECUREBOOT.md     # Detailed Secure Boot design documentation
```

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 1 | VM-stable with Secure Boot, Wayfire desktop | In progress |
| 2 | Bare metal testing (GPU, Wi-Fi, power management) | Planned |
| 3 | Public signed ISO release, Microsoft UEFI CA submission | Planned |

## Tech Stack

| Component | Technology |
|---|---|
| Base | Arch Linux (rolling) |
| Compositor | Wayfire (Wayland) |
| Launcher | Wofi |
| Terminal | Kitty + zsh |
| Theming | adw-gtk3, Fluent icons, Bibata cursor |
| Audio | PipeWire + WirePlumber |
| Boot | shim + GRUB2 + sbsigntools |
| Build | archiso + local AUR repo |
| VM Testing | QEMU/KVM + OVMF Secure Boot firmware |

## License

MIT
