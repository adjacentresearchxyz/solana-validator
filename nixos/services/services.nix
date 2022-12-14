{ config, pkgs, lib, ... }:

{
   services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "8.8.8.8"
    ];
  };

  services.grafana = {
    enable   = true;
    port     = 3000;
    domain   = "localhost";
    protocol = "http";
    dataDir  = "/var/lib/grafana";
    provision = {
        enable = true;
        datasources = [
          {
            type = "loki";
            name = "Loki";
            url = "http://127.0.0.1:3030";
            jsonData.maxLines = 1000;
          }
          { 
            type = "prometheus";
            name = "Prometheus";
            url = "http://127.0.0.1:9090";
          }
          {
            type = "prometheus-alertmanager";
            name = "Prometheus Alertmanager";
            url = "http://localhost:9093";
          }
        ];

        dashboards = [
          {
            name = "tf-declared-dashboards";
            options.path = "/etc/nixos/grafana/dashboards";
          }
        ];
    };
  };

  # nginx reverse proxy
  services.nginx.virtualHosts.${config.services.grafana.domain} = {
    locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        proxyWebsockets = true;
    };
  };

  services.prometheus = {
      enable = true;
      port = 9090;

      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" "processes" ];
          port = 9002;
        };
      };

      scrapeConfigs = [
        {
          job_name = "adjacent";
          static_configs = [{
            targets = [ "127.0.0.1:9002" ];
          }];
        }
      ];

    ruleFiles = [
      (pkgs.writeText "prometheus-rules.yml" (builtins.toJSON {
        groups = [
          {
            name = "alerting-rules";
            rules = import ./alert-rules.nix {inherit lib;};
          }
        ];
      }))
    ];

    alertmanagers = [{
      scheme = "http";
      static_configs = [{
        targets = ["127.0.0.1:9093"];
      }];
    }];

    alertmanager = {
      enable = true;
      configuration = {
        route = {
          receiver = "telegram";
          group_wait = "30s";
          group_interval = "1m";
          group_by = [ "alertname" ];
        };
        receivers = [{
          name = "telegram";
           telegram_configs = [{
            api_url = "https://api.telegram.org";
            bot_token = "5528635417:AAH68RbB6o8F1q5bXF8u0xiEJy837f13Tzw";
            chat_id = -700990737;
            # message = "";
            parse_mode = "HTML";
          }];
        }];
      };
    };
 };

  services.loki = {
    enable = true;
    configuration = {
      server.http_listen_port = 3030;
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
        max_transfer_retries = 0;
      };

      schema_config = {
        configs = [{
          from = "2022-06-06";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };

        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      chunk_store_config = {
        max_look_back_period = "0s";
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        shared_store = "filesystem";
        compactor_ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };

     ruler = {
        enable_api = true;
        enable_alertmanager_v2 = true;
        alertmanager_url = "http://127.0.0.1:9093";
        ring.kvstore.store = "inmemory";
        rule_path = "/var/lib/loki/rules-temp";
        storage = {
          type = "local";
          local.directory = "/var/lib/loki/rules";
        };
      };
    };
  };

  systemd.services.promtail = {
    description = "Promtail service for Loki";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.grafana-loki}/bin/promtail --config.file ${./promtail.yaml}
      '';
    };
  };
  
  # solana validator service file
  # this is for devnet
  systemd.services.solana_validator = {
   enable = true;
   description = "Solana Validator";
   unitConfig = {
     Type = "simple";
     After = "network-online.target";
     Wants="network-online.target";
     StartLimitIntervalSec = 10;
   };
   serviceConfig = {
     ExecStart = "/root/.nix-profile/bin/solana-validator --identity validator-keypair.json --vote-account vote-account-keypair.json --rpc-port 8899 --entrypoint entrypoint.devnet.solana.com:8001 --entrypoint entrypoint2.devnet.solana.com:8001 --entrypoint entrypoint3.devnet.solana.com:8001 --entrypoint entrypoint4.devnet.solana.com:8001 --entrypoint entrypoint5.devnet.solana.com:8001 --limit-ledger-size --log solana-validator.log --known-validator dv1ZAGvdsz5hHLwWXsVnM94hWf1pjbKVau1QVkaMJ92 --known-validator dv2eQHeP4RFrJZ6UeiZWoc3XTtmtZCUKxxCApCDcRNV --known-validator dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB --known-validator dv3qDFk1DTF36Z62bNvrCXe9sKATA6xvVy6A798xxAS";
     WorkingDirectory = "/etc/nixos/solana";
     Restart = "always";
     RestartSec = 25;
   };
   wantedBy = [ "multi-user.target" ];
  };

  # solana validator service file
  # this is for mainnet
  # systemd.services.solana_validator = {
  #  enable = true;
  #  description = "Solana Validator";
  #  unitConfig = {
  #    Type = "simple";
  #    After = "network.target";
  #    StartLimitIntervalSec = 0;
  #  };
  #  serviceConfig = {
  #    ExecStart = "/root/.nix-profile/bin/solana-validator --identity validator-keypair.json --vote-account vote-account-keypair.json --rpc-port 8899 --entrypoint entrypoint.mainnet-beta.solana.com:8001 --entrypoint entrypoint2.mainnet-beta.solana.com:8001 --entrypoint entrypoint3.mainnet-beta.solana.com:8001 --entrypoint entrypoint4.mainnet-beta.solana.com:8001 --entrypoint entrypoint5.mainnet-beta.solana.com:8001 --limit-ledger-size --log solana-validator.log  --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d --expected-shred-version 51382 --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S";
  #    WorkingDirectory = "/etc/nixos/solana";
  #    Restart = "always";
  #    RestartSec = 1;
  #  };
  #  wantedBy = [ "multi-user.target" ];
  # };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true; 
}
