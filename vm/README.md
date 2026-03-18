# ZephyrOS VM Tooling (`vm/`)

This directory contains scripts and defaults for running **ZephyrOS ISOs** in a
VM, with a focus on **QEMU/KVM + OVMF Secure Boot**.

## Files

- `vm.env`  
  Default settings for RAM, CPU count, disk size, OVMF firmware paths, and
  display backend. Can be edited directly or overridden via environment
  variables.

- `run-vm.sh`  
  POSIX shell launcher for QEMU/KVM. It:
  - Discovers the latest `zephyros-*.iso` under `build/out/`
  - Uses **OVMF Secure Boot firmware** as configured in `vm.env`
  - Creates a qcow2 disk image on first run
  - Uses Virtio for disk, network, and GPU where possible

- `test-secureboot.sh`  
  Script intended to run **inside the guest**. It:
  - Confirms UEFI boot mode
  - Queries Secure Boot state via `mokutil`
  - Optionally tests loading a signed vs. unsigned kernel module

## Basic usage

1. Build the ZephyrOS ISO (on an Arch/Arch-based host):

   ```sh
   cd build
   ./build-iso.sh
   ```

2. Launch the VM (on the same host):

   ```sh
   cd vm
   ./run-vm.sh
   ```

3. Inside the VM, after enrolling the development MOK, validate Secure Boot:

   ```sh
   ./test-secureboot.sh
   ```

For module-signing tests:

```sh
./test-secureboot.sh /path/to/signed.ko /path/to/unsigned.ko
```

