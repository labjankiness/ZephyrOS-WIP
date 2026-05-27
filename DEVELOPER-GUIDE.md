# ZephyrOS Developer Guide

How to build, customize, and contribute to ZephyrOS. Pair this with
[DECISIONS.md](DECISIONS.md) for architectural rationale and
[ROADMAP.md](ROADMAP.md) for what's planned next.

## 1. Host requirements

- Arch Linux (or an Arch container) — `archiso` is Arch-specific.
- Packages: `archiso git sudo pacman-contrib base-devel fakeroot debugedit
  grub mtools libisoburn squashfs-tools`.
- Root privileges for `mkarchiso` (the build script uses `sudo`).
- A non-root user for the local-AUR builder — `makepkg` refuses to run as
  root. The scripts detect `$SUDO_USER` automatically.
- ~10 GB free disk for a single edition; ~40 GB for all five.

For CI, the reference environment is the `archlinux:base` container image.
See [`.github/workflows/release.yml`](.github/workflows/release.yml).

## 2. Repository layout

```
zephyros/
├── build/                 # archiso profile + build scripts
│   ├── archiso/           # canonical archiso profile
│   ├── build-iso.sh       # single-ISO legacy builder
│   ├── build-edition.sh   # multi-edition builder (preferred)
│   └── scripts/build-localrepo.sh  # builds AUR packages into a local repo
├── editions/              # edition definitions (base + 4 overlays)
│   ├── base/              # shared packages, dotfiles, scripts
│   └── {scholar,dev,soc,lite}/
├── dotfiles/              # desktop configuration (labwc, kitty, wofi, zsh)
├── secureboot/            # dev MOK keys + signing helpers
├── theme/                 # theme application scripts
├── vm/                    # QEMU/OVMF launch + SB validation
├── docs/                  # landing page (GitHub Pages)
└── *.md                   # design / policy / guides
```

## 3. Building an ISO locally

```sh
cd build
./build-edition.sh core      # or: scholar | dev | soc | lite
ls -lh out/                   # resulting ISO(s)
```

The script:

1. Reads `editions/<edition>/edition.conf` for ISO name, label, and Ollama
   model.
2. Merges `editions/base/packages.x86_64` + edition packages, deduplicating.
3. Copies the archiso profile to a scratch dir (`build/work-<edition>/`).
4. Overlays `editions/base/airootfs/` then `editions/<edition>/airootfs/`
   so edition files override base.
5. Injects the first-boot service, the edition config, and the diagnostic
   scripts (hwreport / bootreport / telemetry-audit).
6. Builds AUR packages into `build/localrepo/` via
   `scripts/build-localrepo.sh` and points pacman at them.
7. Runs `mkarchiso` to emit `build/out/<iso-name>-YYYY.MM.DD-x86_64.iso`.

All five editions build from the same `build/archiso/` profile — edition
differences come entirely from the overlay mechanism.

## 4. Testing in a VM

```sh
cd vm
./run-vm.sh               # QEMU + OVMF Secure Boot firmware
./test-secureboot.sh      # inside the guest — validates SB state
```

`vm/vm.env` holds tunables (disk size, RAM, CPU count). The first boot in a
fresh VM requires enrolling the dev MOK via the shim UI — see
[SECUREBOOT.md §4](SECUREBOOT.md).

## 5. Adding a new edition

1. Create `editions/<name>/edition.conf`:
   ```sh
   EDITION_NAME="myname"
   EDITION_LABEL="ZephyrOS MyName"
   ISO_NAME="zephyros-myname"
   OLLAMA_MODEL="some-model:tag"   # or empty
   ```
2. Add `editions/<name>/packages.x86_64` — edition-only packages.
3. (Optional) Add `editions/<name>/airootfs/` for edition-specific MOTD,
   dotfiles, scripts.
4. Add the edition name to the `matrix.edition` list in
   `.github/workflows/release.yml`.
5. Build locally with `./build-edition.sh myname` and verify the ISO boots.

## 6. Adding a new tool or config

- **Shell tool** under `/usr/local/bin/`: drop the script into
  `editions/base/airootfs/usr/local/bin/` and add a `file_permissions`
  entry in `build-edition.sh`. The installer already copies all
  `zephyros-*` scripts to the installed system — follow that naming.
- **System config** under `/etc/`: drop the file into
  `editions/base/airootfs/etc/…`. Base airootfs is overlaid for every
  edition before the edition overlay runs, so it applies everywhere.
- **systemd unit**: unit file goes in
  `airootfs/usr/lib/systemd/system/`, enablement symlink in
  `airootfs/usr/lib/systemd/system/<target>.target.wants/`.
- **Package**: add to `editions/base/packages.x86_64` (if shared) or the
  edition list (if scoped). AUR packages must be added to the
  `build-localrepo.sh` list so they get built into the local repo.

## 7. Phase 3 diagnostics

Three Markdown-emitting tools ship on every edition:

| Tool | Purpose |
|---|---|
| `zephyros-hwreport` | CPU / GPU / Wi-Fi / BT / audio / firmware / driver snapshot |
| `zephyros-bootreport` | `systemd-analyze` + critical chain + slow-unit flags |
| `zephyros-telemetry-audit` | Static scan for telemetry packages/units/hosts |

All three accept `-o <file>` and have a `--help` flag. Use them in CI
(`zephyros-telemetry-audit --strict`) or in hardware-compat issue reports.

## 8. Release process

Releases are tag-triggered. The workflow in
[`.github/workflows/release.yml`](.github/workflows/release.yml) builds all
five editions, generates checksums, signs with the ZephyrOS GPG release
subkey, and publishes a GitHub Release with auto-generated notes.

To cut a release:

```sh
# 1. Update ROADMAP.md if needed and land changes on main.
# 2. Tag a semantic version.
git tag -a v0.3.0 -m "Phase 3: bare-metal support"
git push origin v0.3.0

# 3. Watch the Actions tab — on success, the release shows up with ISOs,
#    checksums, and signatures attached.
```

The workflow requires three repo secrets to sign builds:

| Secret | Content |
|---|---|
| `GPG_PRIVATE_KEY` | ASCII-armored export of the **signing subkey only** |
| `GPG_KEY_ID` | Long key ID used by `gpg --local-user` |
| `GPG_PASSPHRASE` | Passphrase for the signing subkey |

If these secrets are not set, the workflow still builds and uploads ISOs
+ checksums but skips signing. See [KEYS.md](KEYS.md) for the full key
policy.

## 9. Manual release fallback

If CI is unavailable, build and sign locally:

```sh
cd build
for edition in core scholar dev soc lite; do
    ./build-edition.sh "$edition"
done

cd out
for iso in *.iso; do
    sha256sum "$iso" > "$iso.sha256"
    sha512sum "$iso" > "$iso.sha512"
    gpg --detach-sign --armor --local-user <KEY_ID> "$iso"
    gpg --detach-sign --armor --local-user <KEY_ID> "$iso.sha256"
done
sha256sum *.iso > SHA256SUMS
sha512sum *.iso > SHA512SUMS

# Create the GitHub release via the web UI or `gh` CLI and attach all files.
```

## 10. Contribution workflow

1. Fork, branch, hack.
2. Build the relevant edition ISO locally and boot it in the VM.
3. Run:
   ```sh
   zephyros-hwreport --short
   zephyros-bootreport
   zephyros-telemetry-audit --strict
   ```
   Attach output to the PR if it's hardware/boot/security-adjacent.
4. Open a PR with a clear description and the edition(s) affected.

A clean `zephyros-telemetry-audit --strict` is required to merge — the
project's "no telemetry" stance is enforced, not aspirational.
