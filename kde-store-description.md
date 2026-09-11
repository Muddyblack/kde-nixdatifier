# Nixdatifier

**Nixdatifier** is a panel widget made for NixOS. It shows your system generations, what changed between them, pending flake updates, secrets, and Nix store usage, and lets you roll back or clean up without opening a terminal.
Inspired by Apdatifier.

---

### What's new in this release

*   **Redesigned interface** with four tabs: Generations, Updates, Compare, and Tools.
*   **Package counts on every generation** (added / removed / changed), plus kernel and NixOS release badges.
*   **Inline generation actions:** Activate, Set boot, and Delete right on the expanded card.
*   **Rebuild history:** the output of past switches, cleanups, and updates stays available.
*   **Store usage tool:** find out what keeps a store path from being garbage-collected.
*   **Hash calculator** now gives correct SRI hashes (`sha256-…`) and a ready-to-paste fetcher snippet.
*   **Commands panel** in the footer; the widget waits for your command's real exit status.
*   **Reduced motion option** and lower idle cost: nothing expensive runs while the popup is closed.
*   Also available for **Hyprland** (Quickshell) from the same source; see GitHub.

---

### Features

*   **Generations timeline:** booted and next-boot generations highlighted on one rail, with search across generation numbers, dates, and packages.
*   **Package changes:** added, upgraded, and removed packages for any generation or between any two, with versions, size changes, store paths, and homepage links.
*   **Boot & rollback controls:** activate a generation now, set it for next boot, or delete old ones through Polkit/`pkexec`. The booted and next-boot generations are protected.
*   **Configuration changes:** if your config is in Git, see the `.nix` changes between generations.
*   **Flake update tracker:** checks your flake inputs upstream, notifies you, previews the package changes before you update, and updates single inputs.
*   **Nix store:** store size, free and reclaimable space, and one-click garbage collection.
*   **Secrets inspector:** deployed `sops-nix` / `agenix` secrets and your encrypted source file (format, recipients, freshness). Nothing is decrypted.
*   **Custom commands:** up to four terminal shortcuts (like `nixos-rebuild switch`), run from your flake directory.
*   **Customization:** accent and timeline colors, translucent background, corner radius, font scale, icon style, glow, and motion.

---

### Requirements

The helper scripts use standard tools that are normally present on NixOS:
*   `nix`, `nix-env`, `nix-store` (Nix ≥ 2.19 for SRI hash conversion)
*   `pkexec` / polkit (generation actions and cleanup)
*   `jq` and `git` (flake update checks, history, configuration diffs)
*   Optional: `inotify-tools` (instant sync between widget instances) and `libnotify` (notifications)

---

### Installation

#### 1. From the KDE Store
Right-click your panel → *Add Widgets…* → *Get New Widgets…* and search for **Nixdatifier**.

#### 2. NixOS flake (recommended for NixOS)
The flake package also puts every helper dependency on the widget's `PATH`:

```nix
# flake.nix
{
  inputs.nixdatifier.url = "github:Muddyblack/kde-nixdatifier";

  outputs = { self, nixpkgs, nixdatifier, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            nixdatifier.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  }
}
```

#### 3. Manual
```bash
git clone https://github.com/Muddyblack/kde-nixdatifier.git
cd kde-nixdatifier
kpackagetool6 -t Plasma/Applet -i package
```

Source, issues, and the full settings reference: https://github.com/Muddyblack/kde-nixdatifier
