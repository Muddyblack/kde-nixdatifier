# NixOS Generation Explorer & Flake Update Tracker

A specialized KDE Plasma 6 widget (Plasmoid) for NixOS users to manage and visualize system states directly from the desktop.

## Features

- **Visual Timeline**: Vertical timeline of active and historical NixOS generations.
- **Detailed Info**: Kernel version, NixOS version, and activation time for each generation.
- **Package Diff**: View packages added, upgraded, or removed between generations using `nix store diff-closures`.
- **Rollback / Reboot Action**: Secure wrapper using `pkexec` to switch generations and mark them for next boot.
- **Flake Updates**: Periodically dry-run flake lock file updates to notify you of package upgrades waiting in `nixpkgs-unstable`.

## Installation

To install a test version of the widget:
```bash
./test_install.sh
```

To package it into a `.plasmoid` package:
```bash
./pack.sh
```
