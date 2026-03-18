# ZephyrOS Secure Boot Design

ZephyrOS is designed to **boot under UEFI Secure Boot** from the very first
development phase. This document outlines the boot chain, key handling, and
development workflow.

## 1. Boot chain overview

The intended UEFI boot flow is:

1. UEFI firmware (Secure Boot enabled)
2. `shimx64.efi` (Microsoft-signed shim, or a distro-provided equivalent)
3. `grubx64.efi` (GRUB2 bootloader)
4. Signed Linux kernel image + initramfs

The ISO is built using `archiso` and configured to install and use **shim +
GRUB2** for the UEFI entry. Shim validates GRUB using its built-in trust
database; GRUB then loads a **signed kernel**.

## Shim on vanilla Arch

On **vanilla Arch Linux**, shim is not available as an official repository
package, so ZephyrOS must choose one of these approaches during development:

- **Build shim from AUR (recommended for ZephyrOS builds)**: use the
  `archlinux-shim` AUR package and bake it into the ISO via the ZephyrOS local
  repo build step (see `build/README.md`).
- **Borrow shim from another distro (dev/VM testing only)**: temporarily copy a
  Microsoft-signed `shimx64.efi` from a Fedora/Ubuntu ISO as a stand-in while
  bootstrapping the build pipeline. Do not treat this as a production solution.
- **Use PreLoader for early VM phase**: as a simpler Secure Boot alternative for
  Phase 1 VM validation, PreLoader can be used to avoid shim packaging
  complexity, at the cost of different trust/enrollment semantics.

## 2. Development keys (MOK)

For development, ZephyrOS uses a **self-signed Machine Owner Key (MOK)**:

- Run `secureboot/gen-dev-keys.sh` on the build host to generate:
  - `secureboot/keys/MOK.key` (private key, never committed)
  - `secureboot/keys/MOK.crt` (public certificate)
- The kernel and any custom modules are signed with this key.
- The public certificate is enrolled into the VM firmware via the MOK manager.

> The `secureboot/keys/` directory must be kept **local-only**; do not commit or
> distribute private keys.
>
> **Critical**: `MOK.key` must **never** be committed to Git, copied into the ISO,
> or otherwise distributed. It must remain only on trusted build machines.

## 3. Signing workflow

### 3.1 Kernel signing

After building the kernel (or using a distribution kernel image), sign it with:

```sh
cd secureboot
./gen-dev-keys.sh                 # once, to create MOK.key/MOK.crt
./sign-kernel.sh /path/to/vmlinuz /path/to/vmlinuz.efi
```

The resulting signed kernel (`vmlinuz.efi`) is what GRUB should load on a
Secure Boot system.

### 3.2 Module signing

Out-of-tree or custom kernel modules must be signed before they can be loaded
when Secure Boot enforcement is active:

```sh
cd secureboot
./sign-module.sh /path/to/module.ko
```

This uses `kmodsign` or the kernel’s `sign-file` helper to apply a signature
using the same MOK keypair.

## 4. MOK enrollment inside the VM

To allow the firmware to trust the development MOK:

1. Ensure `MOK.crt` is present inside the guest:
   - Copy it in via shared folder, `scp`, or by embedding it in the ISO.
2. Run, inside the guest:

   ```sh
   cd /path/to/zephyros/secureboot
   ./enroll-mok.sh
   ```

3. Follow the prompts to set a one-time password.
4. Reboot the VM. The **shim/MOK manager UI** will appear:
   - Choose “Enroll MOK”.
   - Confirm the displayed certificate.
   - Enter the password you set.
5. Boot back into ZephyrOS and verify with:

   ```sh
   mokutil --sb-state
   ```

## 5. Verifying Secure Boot in the guest

Use the helper script under `vm/`:

```sh
cd /path/to/zephyros/vm
./test-secureboot.sh
```

This will:

- Confirm UEFI boot mode.
- Query Secure Boot state via `mokutil`.
- Optionally test the loading of a signed vs. unsigned module if you pass
  module paths:

```sh
./test-secureboot.sh /path/to/signed.ko /path/to/unsigned.ko
```

## 6. Production considerations (Phase 3 TODOs)

For a public ZephyrOS release, the Secure Boot story must be hardened:

- **Shim submission**:
  - Prepare a dedicated shim build for ZephyrOS.
  - Follow the official process to submit shim to the **Microsoft UEFI CA** for
    signing.
- **Key management policy**:
  - Define clear rules for key generation, storage, and rotation.
  - Decide how users can enroll their own keys and handle revocations.
- **Separation of keys**:
  - Use distinct keys for:
    - shim / bootloader trust chain.
    - kernel image signing.
    - module signing.
- **Documentation and tooling**:
  - Provide user-facing docs describing risks and options for Secure Boot,
    including how to opt out (e.g. disable Secure Boot in firmware) if needed.

