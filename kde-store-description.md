# Nixdatifier

**Nixdatifier** is  designed specifically for NixOS users. It brings system profile inspections, rollback management, and configuration insights directly to your desktop panel.
Inspired by apdatifier.

Whether you want to track changes between system generations, inspect decrypted secrets, or run custom rebuild scripts, Nixdatifier provides a glassmorphic dashboard to monitor your NixOS system.

---

### Key Features

*   **Generations Timeline** – View active, booted, and pending (next-boot) system generations in a clean visual flow chart.
*   **Closure Package Diffs** – Compare generations and view added, upgraded, or removed packages with target version numbers and size change details.
*   **Boot & Rollback Controls** – Effortlessly switch active profiles, target next-boot selections, or prune old generations safely using Polkit/`pkexec`.
*   **Flake Update Tracker** – Query and notify on pending updates in your NixOS configuration input locks directly from the widget.
*   **Custom Command Actions** – Pin up to 4 terminal command shortcuts (like `nixos-rebuild switch` or `nix flake update`) directly into the widget header.
*   **Secrets Inspector** – Audit active decryptions, modification times, and paths for deployed `sops-nix` or `agenix` secrets.
*   **Frosty Customization** – Complete UI styling control including frosted glass translucency, custom border radius, custom icon modes (colored, monochrome, or accent-tinted), and layout choices.

---

### Requirements

To query system details, the helper scripts in the widget call the following standard commands:
*   `nix` (for `diff-closures` and dry-running flake lock updates)
*   `nix-env` (for profile lists)
*   `pkexec` / `polkit` (for managing system-level profiles)
*   `sops` / `age` (optional: for secrets metadata checks)

---

### Installation & NixOS Configuration

#### 1. NixOS Flake Configuration (Recommended)
You can include the widget directly in your NixOS configuration system packages by adding it as a flake input:

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

#### 2. Manual CLI Installation
Alternatively, install the packaged `.plasmoid` directly to your local KDE environment:

```bash
# Clone the repository
git clone https://github.com/Muddyblack/kde-nixdatifier.git
cd kde-nixdatifier

# Package and install the widget
./pack.sh
kpackagetool6 -t Plasma/Applet -i package
```