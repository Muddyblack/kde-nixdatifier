self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.nixdatifier;
in
{
  options.programs.nixdatifier = {
    enable = lib.mkEnableOption "Nixdatifier, a tray app for Nix generations, flake updates and dev environments";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.nixdatifier;
      defaultText = lib.literalExpression "inputs.nixdatifier.packages.\${system}.nixdatifier";
      description = "The Nixdatifier package to install.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Nixdatifier in the tray when you log in.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."autostart/nixdatifier.desktop" = lib.mkIf cfg.autostart {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Nixdatifier
        Exec=${cfg.package}/bin/nixdatifier --background
        Icon=nixdatifier
        X-GNOME-Autostart-enabled=true
      '';
    };
  };
}
