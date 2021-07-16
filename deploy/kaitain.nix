{ lib, config, pkgs, ... }:
let
  # I'm not using this yet, but it should work like this
  taskserverDataDir = "/home/tasks/data";
  hostname = "gnu.lv";
in
{
  imports =
    [
      ./hardware/linode.nix
    ];

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;

  networking = {
    hostName = "kaitain";
    extraHosts = "

    ";
    nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = [ "wg0" ];
    };
    useDHCP = false;
    usePredictableInterfaceNames = false;
    interfaces = {
      eth0 = {
        useDHCP = true;
        tempAddress = "disabled";
      };
    };
    firewall = {
      enable = true;
      allowedUDPPorts = [ 51820 5349 5350 ];
      allowedTCPPorts = [ 25 80 443 3478 3479 ];
    };
  };

  time.timeZone = "America/New_York";

  services = {
    openssh = {
      enable = true;
      permitRootLogin = "prohibit-password";
    #  authorizedKeysCommand = "${pkgs.cmatrix} \"%u\" \"%h\" \"%t\" \"%k\"";
    #  authorizedKeysCommandUser = "root";
    };
    emacs = {
      enable = true;
      defaultEditor = true;
    };
    solr.enable = true;
    taskserver = {
      enable = true;
      #dataDir = taskserverDataDir;
      organisations = {
        Test = {
          groups = [ "staff" "outsiders" ];
          users = [ "alice" "bob" ];
        };
        Ciphertechnics = {
          users = [ "foo" "bar" ];
        };
      };
    };
    gitDaemon = {
      enable = true;
    };
    nginx = {
      enable = true;
      virtualHosts = {
        "matrix.${hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://localhost:8008";
          };
        };
        "element.${hostname}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            root = pkgs.element-web;
          };
        };

        ${config.services.jitsi-meet.hostName} = {
          enableACME = true;
          forceSSL = true;
        };
      };

      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
    };

    matrix-synapse = {
      enable = true;
      server_name = "${hostname}";
      enable_metrics = true;
      enable_registration = true;
      database_type = "psycopg2";
      database_args = {
        password = "synapse";
      };
      listeners = [
        {
          port = 8008;
          tls = false;
          resources = [
            {
              compress = true;
              names = ["client" "webclient" "federation"];
            }
          ];
        }
      ];
      turn_uris = [
        "turn:turn.${hostname}:3478?transport=udp"
        "turn:turn.${hostname}:3478?transport=tcp"
      ];
      turn_shared_secret = config.services.coturn.static-auth-secret;
    };
    postgresql = {
      enable = true;
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
            TEMPLATE template0
            LC_COLLATE = "C"
            LC_CTYPE = "C";
        '';
    };
    jitsi-meet = {
      enable = true;
      hostName = "jitsi.${hostname}";
      videobridge.enable = true;
    };
    jitsi-videobridge = {
      enable = true;
      openFirewall = true;
    };
    coturn = {
      enable = true;
      use-auth-secret = true;
      static-auth-secret = "oDDY4UkzHfCaXEgoSgj8lXvdZGjgzG4y8YOnficZQPo0p4HE70lMK77hpUr8Vbuq";
      realm = "turn.${hostname}";
      no-tcp-relay = true;
      no-tls = true;
      no-dtls = true;
      extraConfig = ''
        user-quota=12
        total-quota=1200
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255

        allowed-peer-ip=192.168.191.127
    '';
    };
    borgbackup = {
      # jobs.home-danbst = {
      #   paths = "${taskserverDataDir}";
      #   encryption.mode = "none";
      #   environment.BORG_RSH = "ssh -i /home//.ssh/id_ed25519";
      #   repo = "ssh://user@example.com:23/path/to/backups-dir/home-danbst";
      #   compression = "auto,zstd";
      #   startAt = "daily";
      # };
    };
  };
  secrets.files.coturn.file = ./coturn;
  secrets.files.coturn.user = "root";
  #environment.etc.foo.source = config.secrets.files.foo.file;

  nixpkgs.overlays = [
    (self: super: {
      element-web = super.element-web.override {
        conf = {
          default_server_config = {
            "m.homeserver" = {
              "base_url" = "https://matrix.${hostname}";
              "server_name" = "${hostname}";
            };
            "m.identity_server" = {
              "base_url" = "https://vector.im";
            };
          };

          ## jitsi will be setup later,
          ## but we need to add to Riot configuration
          jitsi.preferredDomain = "jitsi.${hostname}";
        };
      };
    })
  ];

  environment = {
    systemPackages = with pkgs; [
      cmatrix
      inetutils
      mtr
      ranger
      sysstat
      element-web
      #steamPackages.steamcmd
      #docker-compose
      git
    ];
    variables = {
      TERM = "xterm-color";
    };

  };
  virtualisation = {
    docker = {
      enable = true;
    };
  };

  sound.enable = false;

  users = {
    motd = "
      Kaitain. Home to the Emperor of the Known Universe.
    ";
    users = {
      tasks = {
        home = "/home/tasks";
        isNormalUser = true;
        description = "Taskwarrior Account";
        openssh.authorizedKeys.keys = import ./pubkeys/tasks.nix { inherit pkgs; };
      };
      tgunnoe = {
        isNormalUser = true;
        home = "/home/tgunnoe";
        description = "Taylor Gunnoe";
        extraGroups = [ "wheel" "networkmanager" "docker" ];
        openssh.authorizedKeys.keyFiles = [ ./pubkeys/tgunnoe ];
      };
      root = {
        openssh.authorizedKeys.keyFiles = [ ./pubkeys/root ];
      };
    };
  };

  security = {
    acme = {
      acceptTerms = true;
      email = "t@gvno.net";

    };
  };

  system.stateVersion = "20.03";

}
