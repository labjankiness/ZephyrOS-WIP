# ZephyrOS User Guide

A practical guide to installing, using, and maintaining ZephyrOS. For design
rationale see [DECISIONS.md](DECISIONS.md); for the Secure Boot story see
[SECUREBOOT.md](SECUREBOOT.md) and [KEYS.md](KEYS.md).

## 1. Choosing an edition

| Edition | You want… | Min RAM |
|---|---|---|
| **Core** | A minimal Wayfire desktop, no AI | 4 GB |
| **Scholar** | Notes/PDF tools + an AI tutor (Phi-3 Mini) | 8 GB |
| **Dev** | A coding setup with a local code model | 16 GB |
| **SOC** | Network / packet tools + an analyst AI | 16 GB |
| **Lite** | Low-end hardware, smallest AI | 4 GB |

Each ISO is self-contained — pick one, write it to a USB stick, and boot.

## 2. Downloading and verifying

Every release ships with:

- The ISO for each edition.
- A `.sha256` and `.sha512` file per ISO.
- `SHA256SUMS` / `SHA512SUMS` aggregate manifests.
- A `.asc` detached GPG signature per file.

Verify before booting:

```sh
# Checksums
sha256sum -c SHA256SUMS

# GPG signature (import the ZephyrOS signing key first — fingerprint is
# printed on each release page)
gpg --verify zephyros-dev.iso.asc zephyros-dev.iso
```

If either step fails, **do not boot the image** — re-download and retry.

## 3. Writing the ISO to USB

**Linux / macOS:**

```sh
sudo dd if=zephyros-dev.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

(Replace `/dev/sdX` with your USB device. Use `lsblk` or `diskutil list` to
find it. **Double-check — `dd` to the wrong device destroys data.**)

**Windows:** use [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.io)
in DD mode.

## 4. Booting and installing

1. Boot the USB stick in **UEFI mode** (required — ZephyrOS does not support
   legacy BIOS).
2. At the welcome dialog, pick **Install ZephyrOS**.
3. Follow the TUI installer: disk → partitions → user → timezone →
   bootloader. See [editions/base/airootfs/usr/local/bin/zephyros-install](editions/base/airootfs/usr/local/bin/zephyros-install)
   for the exact flow.
4. Reboot, remove the USB, and log in.

Wayfire starts automatically on `tty1`. If something goes wrong, drop to a
shell with `Ctrl+Alt+F2` and inspect `/tmp/zephyros-install.log`.

### Installation options

The installer asks a few things beyond disk and user account:

- **Disk encryption (LUKS2)** — optional but recommended for laptops. If you
  enable it, you choose a passphrase that you'll enter **at every boot** to
  unlock the disk. Lose it and the data is unrecoverable. Technically: only the
  root partition is encrypted; the EFI partition (kernel + initramfs) stays
  unencrypted and is mounted at `/boot`, so there's a single passphrase prompt
  at boot rather than two.
- **Keyboard layout & locale** — pick your console keymap (e.g. `us`, `de`,
  `fr`) and system locale (language + number/date formats). No longer hardcoded
  to US English.
- **Swap** — a swapfile sized to your RAM (capped at 8 GiB) is created
  automatically. On unencrypted installs, hibernation (suspend-to-disk) is
  wired up via `resume=` as well; on encrypted installs you get swap without
  hibernation.
- **Firewall** — a default-deny inbound `nftables` ruleset is installed and
  enabled. Nothing accepts inbound connections until you open a port in
  `/etc/nftables.conf` (see the **Firewall** section).

## 5. First-boot (AI model)

On first boot of any AI-bearing edition, a systemd oneshot
(`zephyros-firstboot.service`) pulls the edition's Ollama model. This needs
internet and may take several minutes.

Check progress:

```sh
journalctl -u zephyros-firstboot.service -f
```

Once the model is pulled, use the unified wrapper:

```sh
zephyros-ai                           # interactive chat (role-scoped prompt)
zephyros-ai "summarize this paper"    # one-shot query
ollama run <model>                    # direct model access
```

## 6. Power management (laptops)

TLP is enabled by default. It picks AC vs battery profiles automatically.
Override behavior in `/etc/tlp.d/99-local.conf` — your file wins over the
ZephyrOS baseline in `/etc/tlp.d/00-zephyros.conf`.

Check current state:

```sh
tlp-stat -s            # summary
tlp-stat -b            # battery detail
```

Thermal throttling on Intel CPUs is handled by `thermald` (no user action).

> **Note:** ZephyrOS uses `tlp` for power management. `tlp` and
> `power-profiles-daemon` (PPD) cannot run together — installing PPD will
> mask `tlp` and silently change behavior. If you prefer PPD (e.g. for the
> GNOME power-mode UI), explicitly disable `tlp.service` first:
>
> ```sh
> sudo systemctl disable --now tlp.service
> sudo pacman -S power-profiles-daemon
> sudo systemctl enable --now power-profiles-daemon.service
> ```

## 7. Firewall

ZephyrOS ships a default-deny inbound firewall using `nftables`, enabled on
install. Outbound traffic is allowed; nothing inbound is accepted unless you
open it.

Inspect the live ruleset:

```sh
sudo nft list ruleset
```

To open a port, edit `/etc/nftables.conf` (uncomment one of the example lines
or add your own), then reload:

```sh
sudo systemctl reload nftables
```

For example, to allow incoming SSH, uncomment `tcp dport 22 accept` in the
`input` chain. The file is commented to show the common cases (SSH, web,
mDNS, WireGuard).

## 8. Hardware and boot diagnostics

ZephyrOS ships three diagnostic wrappers that produce Markdown reports —
ideal for pasting into GitHub issues.

```sh
# Full hardware / driver / firmware report
zephyros-hwreport -o /tmp/hw.md

# Boot timing with critical chain + slow-unit flags
zephyros-bootreport --threshold 500ms -o /tmp/boot.md

# Static scan for telemetry/tracking packages and services
zephyros-telemetry-audit -o /tmp/audit.md
```

Run them after any system change you suspect hurt performance or hardware
support, and attach the report to the issue.

## 9. Updates

ZephyrOS is Arch-based and rolling. Standard pacman commands apply:

```sh
sudo pacman -Syu                      # update everything
sudo pacman -S <package>              # install
flatpak update                        # update flatpak apps
ollama pull <model>                   # refresh an AI model
```

Major ZephyrOS changes (new editions, new defaults) are announced in release
notes. Read them before upgrading across tagged releases.

## 10. Secure Boot

On a fresh install, ZephyrOS boots under Secure Boot only if the firmware
already trusts either the Microsoft UEFI CA (via shim) or you've enrolled
the ZephyrOS kernel cert as a MOK. See [SECUREBOOT.md](SECUREBOOT.md) §4
for enrollment steps.

To confirm Secure Boot is active:

```sh
mokutil --sb-state
bootctl status | head -20
```

To opt out, disable Secure Boot in firmware — ZephyrOS still boots, just
without the kernel-integrity guarantee.

## 11. Reporting issues

When filing a hardware or boot issue, please attach:

1. Output of `zephyros-hwreport`.
2. Output of `zephyros-bootreport` if boot/perf related.
3. The installer log (`/tmp/zephyros-install.log`) if it happened during
   install.
4. `journalctl -b -p warning` for the affected boot.

Open issues at <https://github.com/labjankiness/ZephyrOS/issues>.
