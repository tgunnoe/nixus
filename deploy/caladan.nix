{ lib, config, pkgs, ... }:
let
  shcfg = config.services.sourcehut;
in
{

  imports = [
    ./hardware/v2d-config.nix
  ];

  networking = {
    hostName = "caladan";
    domain = "gnu.lv";
    firewall = {
      enable = true;
      interfaces.ens3 = let
        range = with config.services.coturn; [ {
          from = min-port;
          to = max-port;
        } ];
      in
        {
          allowedUDPPortRanges = range;
          allowedUDPPorts = [
            5349 5350 51820 1025 1143 8080
          ];
          allowedTCPPortRanges = range;
          allowedTCPPorts = [
            80 443 1025 3478 3479 8008 53589
            5007 5001 5002 5003 5004 5005 5006 5011 5014
            5107 5101 5102 5103 5104 5105 5106 5111 5114
            9418 4050 6000
          ];
        };
    };
  };

  time.timeZone = "America/New_York";

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nixpkgs.overlays = [
    (self: super: {
      element-web = super.element-web.override {
        conf = {
          default_server_config = {
            "m.homeserver" = {
              "base_url" = "https://matrix.${config.networking.domain}";
              "server_name" = "${config.networking.domain}";
            };
            "m.identity_server" = {
              "base_url" = "https://vector.im";
            };
          };

          jitsi.preferredDomain = "jitsi.${config.networking.domain}";
        };
      };
    }
    )
  ];

  services = {
    sourcehut = {
      enable = true;
      services = [
        "meta"
        "todo"
        "git"
        "hub"
        "builds"
        "lists"
        "man"
        "paste"
        "dispatch"
      ];
      originBase = "${config.networking.domain}";
      meta = {
        port = 5007;
      };
      builds.enableWorker = true;
      builds.images =
        let
          # Pinning to unstable to allow usage with flakes and limit rebuilds.
          pkgs_unstable = builtins.fetchGit {
            url = "https://github.com/NixOS/nixpkgs";
            rev = "ff96a0fa5635770390b184ae74debea75c3fd534";
            ref = "nixos-unstable";
          };
          image_from_nixpkgs = pkgs_unstable: (import ("${pkgs.sourcehut.buildsrht}/lib/images/nixos/image.nix") {
            pkgs = (import pkgs_unstable { });
          });
        in
          {
            nixos.unstable.x86_64 = image_from_nixpkgs pkgs_unstable;
          };
      settings."sr.ht" = {
        environment = "production";
        site-name = "Caladan";
        site-blurb = "forge of the Atredies";
        owner-name = "Tgunnoe";
        owner-email = "tgunnoe@gnu.lv";
        global-domain = "${config.networking.domain}";
        origin = "https://${config.networking.domain}";
        secret-key= "${builtins.readFile ./secrets/sourcehut/secret_key}";
        network-key = "${builtins.readFile ./secrets/sourcehut/network_key}";
        service-key = "${builtins.readFile ./secrets/sourcehut/service_key}";
        private-key= "${builtins.readFile ./secrets/sourcehut/private_key}";
      };
      settings."dispatch.sr.ht" = {
        origin = "https://dispatch.${config.networking.domain}";
      };
      settings."git.sr.ht" = {
        origin = "https://git.${config.networking.domain}";
        outgoing-domain = "https://git.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/git_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/git_client_secret}";
        repos = "/var/lib/git";
      };
      settings."hub.sr.ht" = {
        origin = "https://code.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/code_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/code_client_secret}";
      };
      settings."builds.sr.ht" = {
        origin = "https://builds.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/builds_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/builds_client_secret}";
      };
      settings."builds.sr.ht::worker".name = "localhost:12345";
      settings."lists.sr.ht" = {
        origin = "https://lists.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/lists_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/lists_client_secret}";
      };
      settings."man.sr.ht" = {
        origin = "https://man.${config.networking.domain}";
      };
      settings."paste.sr.ht" = {
        origin = "https://paste.${config.networking.domain}";
        oauth-client-id =
          "${builtins.readFile ./secrets/sourcehut/paste_client_id}";
        oauth-client-secret =
          "${builtins.readFile ./secrets/sourcehut/paste_client_secret}";
      };
      settings."todo.sr.ht" = {
        origin = "https://todo.${config.networking.domain}";
      };
      settings."meta.sr.ht::settings".registration = "no";
      settings."meta.sr.ht::settings".onboarding-redirect =
        shcfg.settings."meta.sr.ht".origin;
      settings."meta.sr.ht" = {
        origin = "https://meta.${config.networking.domain}";
      };
      settings.webhooks = {
        origin = "https://${config.networking.domain}";
        private-key =
          "${builtins.readFile ./secrets/sourcehut/webhooks_private_key}";
      };
      settings.mail = {
        smtp-host = "localhost";
        smtp-port = 1025;
        smtp-user = "org@gnu.lv";
        smtp-from = "org@gnu.lv";
        smtp-password = "${builtins.readFile ./secrets/smtp_pass}";
      };
    };
    openssh = {
      enable = true;
      permitRootLogin = "prohibit-password";
      #authorizedKeysCommand = "${pkgs.cmatrix} \"%u\" \"%h\" \"%t\" \"%k\"";
      authorizedKeysCommandUser = "root";
    };
    emacs = {
      enable = true;
      defaultEditor = true;
      package = pkgs.emacs-nox;
    };
    solr.enable = true;
    taskserver = {
      enable = true;
      fqdn = "tasks.gnu.lv";
      debug = false;
      listenHost = "::";
      listenPort = 53589;
      dataDir = "/data";
      organisations = {
        Atredies = {
          groups = [ "staff" "outsiders" ];
          users = [ "leto" "paul" "gurney"];
        };
      };
    };

    nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "matrix.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://localhost:8008";
            # extraConfig = ''
            #   return 404;
            # '';
          };
          locations."/_matrix" = {
            proxyPass = "http://localhost:8008";
          };
        };
        "element.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            root = pkgs.element-web;
          };
        };

        "bot.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:4050";
          locations."/".proxyWebsockets = true;
        };

        ${config.services.jitsi-meet.hostName} = {
          enableACME = true;
          forceSSL = true;
        };
        "${config.networking.domain}" = {
          enableACME = true;
          forceSSL = true;
          root = "/var/www/gnu.lv/build";
          locations."/".proxyPass = lib.mkForce null;
          locations."/query".proxyPass = lib.mkForce null;
          locations."/static".root = lib.mkForce null;

          locations."= /.well-known/matrix/server".extraConfig =
            let
              server = {
                "m.server" = "matrix.${config.networking.domain}:443";
              };
            in ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON server}';
          '';
          locations."= /.well-known/matrix/client".extraConfig =
            let
              client = {
                "m.homeserver" =  {
                  "base_url" = "https://matrix.${config.networking.domain}";
                };
                "m.identity_server" =  {
                  "base_url" = "https://vector.im";
                };
              };
            in ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON client}';
          '';
        };
        "builds.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5002";
          locations."/query".proxyPass = "http://127.0.0.1:5102";
          locations."/static".root = "${pkgs.sourcehut.buildsrht}/${pkgs.sourcehut.python.sitePackages}/buildsrht";
        };
        "dispatch.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5005";
          locations."/query".proxyPass = "http://127.0.0.1:5105";
          locations."/static".root = "${pkgs.sourcehut.dispatchsrht}/${pkgs.sourcehut.python.sitePackages}/dispatchsrht";
        };
        "git.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5001";
          locations."/query".proxyPass = "http://127.0.0.1:5101";
          locations."/static".root = "${pkgs.sourcehut.gitsrht}/${pkgs.sourcehut.python.sitePackages}/gitsrht";
        };
        "lists.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5006";
          locations."/query".proxyPass = "http://127.0.0.1:5106";
          locations."/static".root = "${pkgs.sourcehut.listssrht}/${pkgs.sourcehut.python.sitePackages}/listssrht";
        };
        "man.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5004";
          locations."/query".proxyPass = "http://127.0.0.1:5104";
          locations."/static".root = "${pkgs.sourcehut.mansrht}/${pkgs.sourcehut.python.sitePackages}/mansrht";
        };
        "meta.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5007";
          locations."/query".proxyPass = "http://127.0.0.1:5107";
          locations."/static".root = "${pkgs.sourcehut.metasrht}/${pkgs.sourcehut.python.sitePackages}/metasrht";
        };
        "code.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5014";
          locations."/query".proxyPass = "http://127.0.0.1:5114";
          locations."/static".root = "${pkgs.sourcehut.hubsrht}/${pkgs.sourcehut.python.sitePackages}/hubsrht";

        };
        "hub.${config.networking.domain}" = {
          forceSSL = lib.mkForce false;
          enableACME = false;
        };
        "paste.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5011";
          locations."/query".proxyPass = "http://127.0.0.1:5111";
          locations."/static".root = "${pkgs.sourcehut.pastesrht}/${pkgs.sourcehut.python.sitePackages}/pastesrht";
        };
        "todo.${config.networking.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://127.0.0.1:5003";
          locations."/query".proxyPass = "http://127.0.0.1:5103";
          locations."/static".root = "${pkgs.sourcehut.todosrht}/${pkgs.sourcehut.python.sitePackages}/todosrht";
        };
      }; # virtualhosts
    };

    matrix-synapse = with config.services.coturn; {
      enable = true;
      server_name = "${config.networking.domain}";
      enable_metrics = true;
      enable_registration = true;
      federation_rc_concurrent = "0";
      federation_rc_reject_limit = "0";
      registration_shared_secret =
        "${builtins.readFile ./secrets/matrix_registration}";
      verbose = "0";
      database_type = "psycopg2";
      database_args = {
        password = "synapse";
      };
      listeners = [
        {
          port = 8008;
          bind_address = "";
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              compress = true; #in place of load balancer
              names = ["client" "webclient" "federation"];
            }
          ];
        }
      ];
      turn_uris = [
        "turn:${realm}:3478?transport=udp"
        "turn:${realm}:3478?transport=tcp"
      ];
      turn_shared_secret = static-auth-secret;
      turn_user_lifetime = "1h";
      public_baseurl = "https://matrix.gnu.lv/";
      extraConfig = ''
        retention:
          enabled: true
          default_policy:
            min_lifetime: 0d
            max_lifetime: 7d
          allowed_lifetime_max: 2y
          purge_jobs:
          - longest_max_lifetime: 2w
            interval: 7d
        encryption_enabled_by_default_for_room_type: all
        email:
          smtp_host: localhost
          smtp_port: 1025
          smtp_user: "org@gnu.lv"
          smtp_pass: "${builtins.readFile ./secrets/smtp_pass}"
          notif_from: "%(app)s Matrix server <org@gnu.lv>"
          app_name: caladan
          client_base_url: "https://element.${config.networking.domain}"
        auto_join_rooms:
          - "#dev:gnu.lv"
          - "#markets:gnu.lv"
          - "#research:gnu.lv"
          - "#sysop:gnu.lv"
          - "#announce:gnu.lv"
      '';
    };
    go-neb = {
      enable = false;
      baseUrl = "https://bot.${config.networking.domain}";
      config = {
        clients = [{
          UserID = "@b1-66er:gnu.lv";
          AccessToken =
            "${builtins.readFile ./secrets/matrix_bot_access_token}";
          DeviceID = "DANYXDWIGI";
          HomeserverURL = "http://localhost:8008";
          Sync = true;
          AutoJoinRooms = true;
          DisplayName = "B1-66ER";
          AcceptVerificationFromUsers = [":localhost:8008"];
        }];
        realms = [
          {
            ID = "github_realm";
            Type =  "github";
            Config = {};
          }
        ];
        sessions = [
          {
            SessionID = "github_session";
            RealmID = "github_realm";
            UserID = "@b1-66er:gnu.lv";
            Config = {
              AccessToken =
                "${builtins.readFile ./secrets/github_session_token}";
              Scopes = "admin:org_hook,admin:repo_hook,repo,user";
            };
          }
        ];
        services = [
          {
            ID = "echo_service";
            Type = "echo";
            UserID = "@b1-66er:gnu.lv";
            Config = {};
          }
          {
            ID = "github_webhook_service";
            Type = "github-webhook";
            UserID = "@b1-66er:gnu.lv";
            Config = {
              RealmID = "github_realm";
              ClientUserID = "@b1-66er:gnu.lv";
              Rooms = {
                "!MODZOZydPqCRdulXmR:gnu.lv" = {
                  Repos = {
                    "zktgunnoe/test" = {
                        Events = ["push" "issues" "pull_requests" ];
                      };
                  };
                };
                "!vGesDLlJvGYvCvlqvU:gnu.lv" = {
                  Repos = {
                    "zktgunnoe/test" = {
                        Events = ["push" "issues" "pull_request" ];
                      };
                  };
                };
                "!SbqmlkNmPfTPsCdsdh:gnu.lv" = {
                  Repos = {
                    "zktgunnoe/test" = {
                        Events = ["push" "issues" "pull_request" ];
                      };
                  };
                };
              };
            };
          }

          {
            ID = "github_cmd_service";
            Type = "github";
            UserID = "@bot:gnu.lv"; # requires a Syncing client
            Config = {
              RealmID = "github_realm";
            };
          }
        ];
      };
    };
    redis = {
      enable = true;
    };
    dockerRegistry = {
      enable = true;
      port = 6000;
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
      hostName = "jitsi.${config.networking.domain}";
      videobridge.enable = true;
    };
    jitsi-videobridge = {
      enable = true;
      openFirewall = true;
    };
    coturn = rec {
      enable = true;
      use-auth-secret = true;
      static-auth-secret = "${builtins.readFile ./secrets/coturn}";
      realm = "turn.${config.networking.domain}";
      no-tcp-relay = true;
      no-tls = true;
      no-dtls = true;
      no-cli = true;
      min-port = 49000;
      max-port = 50000;
      # cert = "${config.security.acme.certs.${realm}.directory}/full.pem";
      # pkey = "${config.security.acme.certs.${realm}.directory}/key.pem";

      extraConfig = ''
        user-quota=12
        total-quota=1200
        # for debugging
        verbose
        # ban private IP ranges
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.88.99.0-192.88.99.255
        denied-peer-ip=244.0.0.0-224.255.255.255
        denied-peer-ip=255.255.255.255-255.255.255.255
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
  security = {
    acme = {
      acceptTerms = true;
      email = "tgunnoe@gnu.lv";
    };
  };

  environment = {
    systemPackages = with pkgs; [
      cmatrix
      gnutls
      inetutils
      mtr
      ranger
      sysstat
      element-web
      docker-compose
      matrix-synapse
      taskwarrior
      libressl
      lsof
      nmap
      git

      jq
      screen
      hydroxide

      python
      python38Packages.virtualenv

      tcpdump
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
    Welcome to planet Caladan. Home of House Atredies.
";
    users = {
      git = {
        home = "/var/lib/git";
      };
      tasks = {
        home = "/home/tasks";
        isNormalUser = true;
        description = "Taskwarrior Account";
        extraGroups = [ "taskd" ];
        openssh.authorizedKeys.keys =
          import ./pubkeys/tasks.nix { inherit pkgs; };
      };
      tgunnoe = {
        isNormalUser = true;
        home = "/home/tgunnoe";
        description = "Tgunnoe";
        extraGroups = [ "wheel" "networkmanager" "taskd" ];
        openssh.authorizedKeys.keyFiles = [ ./pubkeys/tgunnoe ];
      };
      root = {
        openssh.authorizedKeys.keyFiles = [ ./pubkeys/root ];
      };
    };
  };

  system.stateVersion = "20.09";

}
