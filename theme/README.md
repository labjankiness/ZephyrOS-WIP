# ZephyrOS Theming (`theme/`)

This directory contains the **theming pipeline** for ZephyrOS.

## Files

- `apply-theme.sh`  
  POSIX script that installs configuration files from `dotfiles/` into the
  target user’s home directory and prepares the Wayfire-based desktop to use
  the ZephyrOS look (centered taskbar, frosted launcher, etc.).

## Usage

From inside a ZephyrOS session:

```sh
cd /path/to/zephyros/theme
./apply-theme.sh        # apply in dark mode (default)
./apply-theme.sh --light
```

By default, it uses `\$HOME` as the target; override with:

```sh
TARGET_USER_HOME=/home/otheruser ./apply-theme.sh
```

GTK/Kvantum and icon themes are currently using the system defaults. They can
be extended later with full ZephyrOS-specific theme assets.

