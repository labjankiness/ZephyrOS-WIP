# ZephyrOS

**[Website & Downloads](https://labjankiness.github.io/ZephyrOS-WIP/)**

A minimal, modern Arch-based Linux distribution with a Wayfire Wayland compositor and UEFI Secure Boot support. Inspired by the Windows 11 aesthetic — centered taskbar, frosted launcher, clean animations — without the bloat.

Ships in **5 editions**, each bundling a locally-hosted AI model via Ollama tailored to a specific use case.

## Editions

| Edition | Target User | AI Model | Min RAM | Key Tools |
|---|---|---|---|---|
| **Core** | Base reference | None | 4 GB | Wayfire desktop, Kitty, Thunar |
| **Scholar** | Students | Phi-3 Mini (3.8B) | 8 GB | Firefox, Evince, Xournal++, AI tutor |
| **Dev** | Developers | DeepSeek Coder V2 16B Lite | 16 GB | Neovim, Helix, Docker, Git, 6 languages |
| **SOC** | Security analysts | Llama 3.1 8B | 16 GB | Wireshark, nmap, tcpdump, AI triage |
| **Lite** | Low-end hardware | SmolLM2 1.7B | 4 GB | Mousepad, Midori, minimal footprint |

All editions share the same base: Wayfire desktop, Secure Boot, Ollama runtime. The AI model is pulled automatically on first boot.

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
                                                    Ollama + AI model
```

**Base:** Arch Linux (rolling release, archiso for reproducible ISOs)
**Display:** Wayfire — lightweight Wayland compositor with blur, rounded corners, animations
**Boot:** shim + GRUB2 Secure Boot chain with development MOK signing
**AI:** Ollama runs locally — zero data exfiltration, all inference on-device

## Key Design Decisions

- **Arch over Debian/Ubuntu** — Rolling model, first-class archiso support, modern Wayland stack
- **Wayfire over KDE Plasma** — Modular plugin-based effects without full DE bloat
- **Secure Boot from day one** — Development MOK workflow validates boot chain early
- **Thunar + Kitty** — Small footprint alternatives to Dolphin and GNOME Terminal
- **Edition system** — Shared base with per-edition package overlays and AI model configs

See [DECISIONS.md](DECISIONS.md) for full rationale.

## Quick Start

**Build an edition ISO** (requires Arch Linux host):
```bash
cd build && ./build-edition.sh scholar   # or: dev, soc, lite, core
```

**Build the base ISO** (original, no editions):
```bash
cd build && ./build-iso.sh
```

**Test in VM** (QEMU/KVM + OVMF):
```bash
cd vm && ./run-vm.sh
```

**Use the AI assistant** (inside any edition):
```bash
zephyros-ai                              # Interactive chat
zephyros-ai "explain quicksort"          # One-shot query
ollama run phi3:mini                      # Direct model access
```

**Run diagnostics** (inside any edition):
```bash
zephyros-hwreport           -o hw.md      # Hardware / driver / firmware report
zephyros-bootreport         -o boot.md    # systemd-analyze + slow-unit flags
zephyros-telemetry-audit    -o audit.md   # Scan for telemetry / phone-home packages
```

**Apply theme** (inside the guest):
```bash
cd theme && ./apply-theme.sh [--light|--dark]
```

## Project Structure

```
zephyros/
├── build/                  # Archiso profile and ISO build scripts
│   ├── build-iso.sh        # Original single-ISO builder
│   └── build-edition.sh    # Multi-edition ISO builder
├── editions/               # Edition definitions
│   ├── base/               # Shared packages, first-boot service, AI wrapper
│   ├── scholar/            # Student edition overlay
│   ├── dev/                # Developer edition overlay
│   ├── soc/                # Security analyst edition overlay
│   └── lite/               # Lightweight edition overlay
├── dotfiles/               # Wayfire, Kitty, Wofi, zsh configs
├── secureboot/             # MOK key generation, kernel/module signing, enrollment
├── theme/                  # Single-command theme application (dark/light)
├── vm/                     # QEMU/OVMF launch and Secure Boot validation
├── DECISIONS.md            # Design decision rationale
├── ROADMAP.md              # 3-phase development plan
├── SECUREBOOT.md           # Detailed Secure Boot design documentation
├── KEYS.md                 # Key management and revocation policy
├── USER-GUIDE.md           # Install, verification, upgrade, diagnostics
└── DEVELOPER-GUIDE.md      # Build, contribute, release
```

## How Editions Work

Each edition is a directory under `editions/` containing:
- **`edition.conf`** — Name, description, ISO filename, Ollama model ID
- **`packages.x86_64`** — Additional packages (merged with base)
- **`airootfs/`** — Files overlaid into the ISO root filesystem (MOTD, configs)

At build time, `build-edition.sh` merges the base profile with the edition overlay and produces a standalone ISO. On first boot, a systemd oneshot service pulls the configured AI model via Ollama.

The `zephyros-ai` command provides a unified interface across all editions — it reads the edition config, loads the appropriate model, and sets a role-specific system prompt (tutor, code assistant, SOC analyst, etc.).

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 1 | VM-stable with Secure Boot, Wayfire desktop | Complete |
| 1.5 | Edition system with AI model integration | Complete |
| 2 | Full installer experience (TUI installer, live session) | Complete |
| 3 | Bare metal testing (GPU, Wi-Fi, power management) | Scaffolded (awaits bare-metal runs) |
| 4 | Public signed ISO release, Microsoft UEFI CA submission | Scaffolded (awaits signing keys + shim submission) |

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
| AI Runtime | Ollama (local inference) |
| Build | archiso + local AUR repo |
| VM Testing | QEMU/KVM + OVMF Secure Boot firmware |

## License

MIT
