{ config, lib, pkgs, ... }:

with lib;

let cfg = config.services.xserver.autorepeat;
in {
  options = {
    services.xserver.autorepeat.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Enable setting keyboard repeat rate";
    };

    services.xserver.autorepeat.delay = mkOption {
      description = "Delay before repeating keys";
      default = 660;
      type = types.int;
    };

    services.xserver.autorepeat.rate = mkOption {
      description = "Repeat rate of keys";
      default = 25;
      type = types.int;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.autorepeat =
      { description = "Keyboard autorepeat rate";
        requires = [ "display-manager.service" ];
        after = [ "display-manager.service" ];
        wantedBy = [ "graphical.target" ];
        serviceConfig.ExecStart = ''
          ${pkgs.xlibs.xset}/bin/xset r rate ${toString cfg.delay} ${toString cfg.rate}
        '';
        environment = { DISPLAY = ":0"; };
        serviceConfig.Restart = "always";
      };
  };
}
