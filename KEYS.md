# ZephyrOS Key Management and Revocation Policy

This document describes the cryptographic keys used by ZephyrOS for Secure
Boot and release signing, how they are stored, how they rotate, and how
revocation is handled. It is a living document — update it whenever the
key set changes.

Companion documents: [SECUREBOOT.md](SECUREBOOT.md), [ROADMAP.md](ROADMAP.md).

## 1. Key inventory

ZephyrOS uses four logically separate keys. Separation is deliberate —
compromise of any one should not invalidate the others.

| Key | Purpose | Type | Where it lives |
|---|---|---|---|
| **ZephyrOS Release** | Sign release ISOs and checksum manifests | GPG (Ed25519) | Offline USB; subkey in CI secret |
| **ZephyrOS Shim** | Vendor certificate embedded in the ZephyrOS-built shim | X.509 (RSA-4096) | Offline hardware token |
| **ZephyrOS Kernel** | Sign kernel images (`vmlinuz.efi`) | X.509 (RSA-3072) | Offline hardware token |
| **ZephyrOS Module** | Sign out-of-tree kernel modules | X.509 (RSA-3072) | Build host, HSM-backed |

The **Shim**, **Kernel**, and **Module** keys replace the single development
MOK keypair used in Phase 1. The development MOK (`secureboot/keys/MOK.key`)
is only valid for local VM testing and **must never appear on a release ISO**.

## 2. Generation

- All keys are generated on an air-gapped machine running a reproducible
  Linux image (documented build log kept with the key fingerprint).
- GPG keys follow the **primary + subkeys** pattern: the primary key is
  certification-only and stays offline. A signing subkey is exported for
  CI use.
- X.509 keys are generated with `openssl req -new -x509 -newkey rsa:N` using
  hardware RNG entropy (`rng-tools` or a hardware token's own generator).

Recommended parameters:

```sh
# Release GPG
gpg --quick-generate-key 'ZephyrOS Release <release@zephyros.example>' \
    ed25519 cert 0   # primary: certify-only, no expiry
gpg --quick-add-key <PRIMARY_FPR> ed25519 sign 2y   # signing subkey, 2y

# Kernel / Module X.509
openssl req -new -x509 -newkey rsa:3072 -sha256 -days 1825 \
    -keyout kernel.key -out kernel.crt \
    -subj "/CN=ZephyrOS Kernel Signing/"
```

## 3. Storage

| Key | Offline master | CI / build-host copy |
|---|---|---|
| Release GPG primary | Hardware token + printed paper backup in sealed envelope | — |
| Release GPG signing subkey | — | GitHub Actions secret `GPG_PRIVATE_KEY` (ASCII-armored export of subkey only) |
| Shim X.509 | Hardware token only | — (used only during shim build) |
| Kernel X.509 | Hardware token | Exported to ephemeral build runner; wiped on teardown |
| Module X.509 | HSM | Same HSM, referenced by slot ID |

Additional secrets required for CI releases:

- `GPG_PRIVATE_KEY` — ASCII-armored export of the signing subkey.
- `GPG_KEY_ID` — long key ID used by the workflow.
- `GPG_PASSPHRASE` — passphrase for the signing subkey.

Rotate these whenever a maintainer with access leaves the project.

## 4. Rotation schedule

| Key | Normal rotation | Forced rotation |
|---|---|---|
| Release GPG signing subkey | Every 2 years, or before expiry | On subkey leak, lost passphrase, or maintainer turnover |
| Release GPG primary | Every 5 years | On primary-key compromise |
| Shim X.509 | With each shim re-submission to the Microsoft UEFI CA (typically every 1–2 years) | On private-key compromise |
| Kernel X.509 | Every 5 years | On private-key compromise |
| Module X.509 | Every 5 years | On private-key compromise |

At each rotation:

1. Generate the new key following §2.
2. Sign the new public key / certificate with the previous one (cross-signing).
3. Publish the new fingerprint in the release notes of the next release and
   on the ZephyrOS website.
4. Update CI secrets and teardown scripts.
5. Retain the old public cert for **signature verification of old
   releases**; retire the old private key to cold storage for 1 year, then
   destroy.

## 5. Revocation

ZephyrOS publishes a single **revocation manifest** at
`secureboot/REVOKED.txt` (and mirrored on the website) listing:

- GPG key fingerprints and their revocation reason/date.
- X.509 certificate SHA-256 fingerprints scheduled for inclusion in the
  UEFI `dbx` (Forbidden Signatures Database).
- Specific kernel image hashes that must no longer be trusted.

On revocation, the following happen in order:

1. **Publish** — the compromised key/cert is added to `secureboot/REVOKED.txt`
   with UTC timestamp and reason; a signed revocation notice is posted to the
   website within 24h of discovery.
2. **Rotate** — generate a replacement key per §2. Cross-sign from the *prior*
   key if that key is still intact; otherwise announce the new fingerprint
   through multiple out-of-band channels.
3. **Rebuild** — re-sign currently shipping artifacts with the replacement
   key and publish a patch release.
4. **Distribute revocation** — for Secure Boot keys, submit the certificate
   hash to the Microsoft UEFI CA process for `dbx` inclusion. For GPG,
   upload the revocation certificate to the keyservers the project uses.
5. **Archive** — store the full incident timeline (how the key was
   compromised, what was re-issued, who was notified) in a public post-mortem.

## 6. User verification

Each release page includes:

- `SHA256SUMS` and `SHA512SUMS` manifests.
- Per-file `.asc` detached signatures (signed by the Release GPG subkey).
- A link to the current GPG public key and its fingerprint.

End-user verification:

```sh
# Import the ZephyrOS signing key (replace URL with the one printed on each release page)
curl -fsSL https://zephyros.example/keys/release.asc | gpg --import

# Verify checksums
sha256sum -c SHA256SUMS

# Verify signature on any file
gpg --verify zephyros-dev.iso.asc zephyros-dev.iso
```

Users who want to enroll the ZephyrOS Kernel cert for custom Secure Boot
configurations can download `ZephyrOS-Kernel.crt` from the release page
and enroll it via `mokutil --import` (same process described in
[SECUREBOOT.md §4](SECUREBOOT.md)).

## 7. Contact and incident response

- Primary contact: security@zephyros.example (PGP-encrypted preferred).
- Fallback: open a private security advisory on the GitHub repository.
- SLA for acknowledging a credible compromise report: 72 hours.
