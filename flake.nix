{
  description = "NixOS Generation Explorer — KDE Plasma 6 widget for managing NixOS generations, package diffs, flake updates, and secrets";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };

      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
      pluginId = metadata.KPlugin.Id;   # org.muddyblack.nixosGenerationExplorer
      version  = metadata.KPlugin.Version;
    in
    {
      # ── installable package ────────────────────────────────────────────────
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname   = "nixos-generation-explorer";
            inherit version;
            src = ./package;

            dontConfigure = true;
            dontBuild     = true;

            installPhase = ''
              runHook preInstall

              # Install plasmoid package
              plasmoid="$out/share/plasma/plasmoids/${pluginId}"
              mkdir -p "$plasmoid"
              cp -r . "$plasmoid/"

              # Register icon in hicolor theme so Plasma Widget Explorer picks it up
              mkdir -p "$out/share/icons/hicolor/256x256/apps"
              cp icon.png "$out/share/icons/hicolor/256x256/apps/${pluginId}.png"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description  = metadata.KPlugin.Description;
              longDescription = ''
                A KDE Plasma 6 widget for NixOS users. Provides a visual generation
                timeline, package diffs between generations (nix store diff-closures),
                one-click rollback/boot actions via pkexec, flake update tracking, and
                a secrets browser — all from the desktop panel.
              '';
              license   = licenses.mit;
              platforms = platforms.linux;
              homepage  = metadata.KPlugin.Website;
              maintainers = [ ];
            };
          };
        });

      # ── `nix run .#view` — preview widget with plasmoidviewer ─────────────
      apps = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              exec nix shell nixpkgs#kdePackages.plasma-sdk -c plasmoidviewer \
                -a "$PWD/package" -f "''${1:-planar}"
            '');
          };
          pack = {
            type = "app";
            program = toString (pkgs.writeShellScript "pack" ''
              set -euo pipefail
              here="$PWD"
              ver="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$here/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
              name="$(basename "$here")"
              out="$here/$name-$ver.plasmoid"
              rm -f "$out"
              (cd "$here/package" && ${pkgs.zip}/bin/zip -r "$out" . -x '*.swp' '*~')
              echo "wrote $out"
            '');
          };
        });

      # ── development shell ──────────────────────────────────────────────────
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.mkShell {
            name = "nixos-generation-explorer-dev";
            packages = with pkgs; [
              qt6.qtdeclarative      # qmllint + qmlformat
              kdePackages.kpackage   # kpackagetool6
              kdePackages.plasma-sdk # plasmoidviewer
              pre-commit
              zip                    # needed by pack.sh
            ];
            shellHook = ''
              pre-commit install -f --install-hooks
              echo "nixos-generation-explorer dev shell ready"
              echo "  make help        — list targets (view, install, pack, tag)"
            '';
          };
        });

      # ── formatter (nixpkgs-fmt via nix fmt) ───────────────────────────────
      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
