{
  description = "NixOS Generation Explorer and Flake Update Tracker widget for KDE Plasma 6";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system);
      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "nixos-generation-explorer";
            version = metadata.KPlugin.Version;
            src = ./package;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              root=$out/share/plasma/plasmoids/org.muddyblack.nixosGenerationExplorer
              mkdir -p "$root"
              cp -r . "$root/"
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "NixOS Generation Explorer and Flake Update Tracker widget for KDE Plasma 6";
              license = licenses.mit;
              platforms = platforms.linux;
              homepage = "https://github.com/muddyblack/KDE-PLASMA";
            };
          };
        });
    };
}
