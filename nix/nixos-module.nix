{ lib, config, pkgs, ... }:
let
  toml = pkgs.formats.toml { };
  configFilePath = toml.generate "config.toml" config.services.prometheus.exporters.garni.settings;
  cfg = config.services.prometheus.exporters.garni;
in
{
  options = {
    services.prometheus.exporters.garni = {
      package = lib.mkOption {
        defaultText = lib.literalMD "`packages.default` from the prometheus-garni-exporter flake";
      };
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable the garni meteo station collector
        '';
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Open port in firewall for incoming connections.
        '';
      };
      settings = {
        server = {
          host = lib.mkOption {
            type = lib.types.str;
            default = "0.0.0.0";
            description = ''Interface to bind to.'';
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8305;
            description = ''Port to listen to.'';
          };
          garniUpdatePath = lib.mkOption {
            type = lib.types.str;
            default = "/weatherstation/updateweatherstation.php";
            description = ''URL path where garni station sent updates.'';
          };
          prometheusV004Path = lib.mkOption {
            type = lib.types.str;
            default = "/metrics/prometheus";
            description = ''URL path where prometheus metrics in v0.0.4 format are presented'';
          };
          prometheusV1Path = lib.mkOption {
            type = lib.types.str;
            default = "/metrics/prometheus_v1";
            description = ''URL path where prometheus metrics in v1.0.0 format are presented'';
          };
          prometheusOpenmetricsPath = lib.mkOption {
            type = lib.types.str;
            default = "/metrics/openmetrics_v1";
            description = ''URL path where openmetrics metrics in v1.0.0 format are presented'';
          };
        };
        logging = {
          level = lib.mkOption {
            type = lib.types.enum [
              "info"
              "debug"
              "warn"
            ];
            default = "info";
            description = ''
              Logging level of the garni-rs.
            '';
          };
        };
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "garni-exporter";
        description = ''
          User name under which the garni exporter shall be run.
        '';
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "garni-exporter";
        description = ''
          Group under which the garni exporter shall be run.
        '';
      };
    };
  };
  config = lib.mkIf cfg.enable {
    users.extraGroups.garni-exporter = { };

    users.extraUsers.garni-exporter = {
      description = "prometheus garni exporter";
      group = "garni-exporter";
      # home = baseDir;
      isSystemUser = true;
    };

    environment.systemPackages = [ cfg.package ];

    systemd.services.prometheus-garni-exporter = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/prometheus_garni_exporter --config-file ${configFilePath}";
        User = cfg.user;
        Group = cfg.group;

        PermissionsStartOnly = true;
        Restart = "always";
        PrivateTmp = true;
        # Hardening
        CapabilityBoundingSet = lib.mkDefault [ "" ];
        DeviceAllow = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;

        ProtectClock = lib.mkDefault true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        ProtectSystem = "full";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.settings.server.port ];

  };
}
