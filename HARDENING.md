# ZephyrOS Hardened — Operator's Guide

A practical guide to the ZephyrOS Hardened edition: what's locked down, what
to enable after install, and how to use the bundled offensive toolkit.

Companion docs: [USER-GUIDE.md](USER-GUIDE.md), [SECUREBOOT.md](SECUREBOOT.md).

## What's hardened by default

| Layer | Mechanism | Status on a fresh install |
|---|---|---|
| Kernel | `linux-hardened` (KSPP patches, more conservative defaults) | Installed; default at GRUB |
| MAC | AppArmor (loaded via `lsm=` cmdline) | `apparmor.service` enabled |
| Audit | Linux audit framework | `auditd.service` enabled |
| USB | USBGuard policy daemon | `usbguard.service` enabled |
| Sandboxing | firejail, bubblewrap | Available; opt-in per app |
| Sysctl | KSPP/CIS network + kernel hardening | `/etc/sysctl.d/99-zephyros-hardening.conf` |
| Module blacklist | Legacy FS, obscure net protocols, FireWire/Thunderbolt | `/etc/modprobe.d/99-zephyros-hardening.conf` |
| Firewall | `nftables` default-deny inbound (from base) | `nftables.service` enabled |
| Secure Boot | shim → GRUB → signed kernel chain (Phase 1/4) | Per `SECUREBOOT.md` |

## Post-install steps

### 1. Initialize the file-integrity database (AIDE)

AIDE detects unexpected file changes — kernel modules, suid binaries, configs.

```sh
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
# Then schedule a daily check:
sudo systemctl enable --now aide-check.timer 2>/dev/null || \
    echo "Add a cron job: 0 5 * * * /usr/bin/aide --check"
```

### 2. Update ClamAV signatures

```sh
sudo freshclam
sudo systemctl enable --now clamav-freshclam.service
```

### 3. Run a Lynis baseline audit

Establishes a hardening score so you can track regressions over time.

```sh
sudo lynis audit system
```

### 4. Tune USBGuard for your devices

Before USBGuard becomes useful you have to teach it about your keyboard,
mouse, dock, and so on. Plug them in, then generate an allow-list:

```sh
sudo usbguard generate-policy > /tmp/usbguard.rules
sudo install -m 0600 -o root -g root /tmp/usbguard.rules /etc/usbguard/rules.conf
sudo systemctl restart usbguard
```

Any device plugged in afterwards is **blocked until you allow it**:

```sh
sudo usbguard list-devices               # what's connected
sudo usbguard allow-device <id>          # one-shot allow
sudo usbguard allow-device <id> -p       # permanent allow
```

### 5. Verify AppArmor profiles

```sh
sudo aa-status
```

If specific apps need confining, install `apparmor-profiles-extra` and
`aa-enforce <profile>` them.

### 6. Confirm the LSM stack is active

```sh
cat /sys/kernel/security/lsm
# Expect: landlock,lockdown,yama,integrity,apparmor,bpf
```

If `apparmor` is missing, the installer's GRUB cmdline edit didn't take —
check `/etc/default/grub`'s `GRUB_CMDLINE_LINUX_DEFAULT` and rerun
`sudo grub-mkconfig -o /boot/grub/grub.cfg`.

## Offensive toolkit (what ships)

The hardened edition includes a curated subset of the standard pentest/DFIR
stack that lives in official Arch repositories — so a build never breaks on
an AUR package vanishing.

| Category | Tools |
|---|---|
| Network / recon | `nmap`, `masscan`, `hping`, `mtr`, `arp-scan`, `sslscan`, `ldns`, `bind-tools` |
| Wireless | `aircrack-ng`, `reaver`, `hostapd` |
| Web testing | `nikto`, `sqlmap`, `gobuster`, `ffuf`, `httpie` |
| Credentials | `hashcat`, `john`, `hydra`, `medusa`, `chntpw` |
| RE / forensics | `radare2`, `gdb`, `ltrace`, `strace`, `binwalk`, `foremost`, `sleuthkit`, `ddrescue`, `testdisk`, `perl-image-exiftool` |
| VPN / crypto | `openvpn`, `wireguard-tools`, `gnupg` |
| Capture | `wireshark-qt`, `tcpdump` |

### Manual installs (not in the ISO)

These are too unreliable to bake into a release but are worth installing on a
working system:

```sh
# pwntools — exploit-dev / CTF helper
python -m venv ~/.venvs/pwn && ~/.venvs/pwn/bin/pip install pwntools

# Metasploit Framework (AUR)
yay -S metasploit

# Burp Suite Community (AUR)
yay -S burpsuite

# Ghidra (AUR)
yay -S ghidra
```

## What's intentionally not hardened

- **Application sandboxing** — `firejail` is installed but no per-app
  profiles are enforced by default. Choose per app: `firejail firefox`,
  `firejail thunderbird`, etc.
- **Outbound firewall** — the base `nftables` ruleset only denies inbound.
  If you want outbound control too, install `opensnitch` (AUR) for an
  interactive prompt-style firewall.
- **Disk encryption** — not specific to the Hardened edition; enable in
  the installer regardless of edition (see USER-GUIDE.md "Installation
  options").
- **Mandatory full-system AppArmor confinement** — only profile-enabled
  apps are confined; system-wide MAC mode (`apparmor=1 security=apparmor
  apparmor.mode=enforce` etc.) is left to the operator.

## Trust boundaries

The hardened edition raises the bar; it does not make the machine bulletproof.
In particular:

- It cannot defend against a malicious operator with root.
- It cannot defend against firmware/UEFI compromise; pair with Secure Boot
  (see [SECUREBOOT.md](SECUREBOOT.md)) and verify shim signatures.
- It cannot defend against side-channel attacks on shared hardware.
- The kernel hardening sysctls are conservative — if a Lynis audit suggests
  going further, do so deliberately and test the changes don't break your
  workflow.

## Reporting hardening issues

Hardening regressions (e.g. AppArmor not enforcing, sysctl override losing
effect, USBGuard blocking known-good devices) are tracked at:

<https://github.com/labjankiness/ZephyrOS/issues>

Tag the issue **`hardened`** and attach the output of:

```sh
sudo lynis audit system --no-colors --quick > /tmp/lynis.txt
zephyros-hwreport -o /tmp/hw.md
```
