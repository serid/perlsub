{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = (pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "cargo"
            "rustc"
            "rustfmt"
          ];
        });
        naersk-lib = naersk.lib."${system}".override {
          cargo = rust;
          rustc = rust;
        };
        envVars = with pkgs; {
          BWRAP = "${bubblewrap}/bin/bwrap";
          PERL = "${perl}/bin/perl";
          PRLIMIT = "${util-linux}/bin/prlimit";
          TIMEOUT = "${coreutils}/bin/timeout";
          ALLOW_DIRS = "${perl},${util-linux},${util-linux.lib},${glibc},${libxcrypt}";
        };
        envString = with pkgs.lib; concatStringsSep " " (mapAttrsToList (name: value:
          throwIf (strings.hasInfix " " value) "Env values shall not contain whitespace"
          (name + "=" + value)) envVars);
      in
      rec {
        packages.perlsub = naersk-lib.buildPackage {
          pname = "perlsub";
          root = ./.;
        };
        packages.run-perlsub = pkgs.writeScriptBin "run-perlsub" ''
          #!/bin/sh
          env ${envString} ${self.defaultPackage.${system}}/bin/perlsub
        '';
        packages.service = pkgs.writeText "perlsub.service" ''
          [Unit]
          After=network.target
          Requires=network.target

          [Service]
          Type=simple
          ExecStart=${self.defaultPackage.${system}}/bin/perlsub
          EnvironmentFile=/etc/perlsub.env
          Environment=${envString}
          User=perlsub
          Group=nogroup

          [Install]
          WantedBy=multi-user.target
        '';
        defaultPackage = packages.perlsub;

        # `nix bundle` searches for a package in `apps` output before checking `packages`
        # so we annotate the app with a suffix
        apps.run-perlsub-app = {
          type = "app";
          program = "${self.packages.${system}.run-perlsub}/bin/run-perlsub";
        };
        defaultApp = apps.run-perlsub-app;

        nixosModules.default = with pkgs.lib; { config, ... }:
          let cfg = config.services.perlsub;
          in
          {
            options.services.perlsub = {
              enable = mkEnableOption "perlsub bot for Telegram";
              envFile = mkOption {
                type = types.str;
                default = "/etc/perlsub.env";
              };
            };
            config = mkIf cfg.enable {
              users.users.perlsub = {
                group = "nogroup";
                isSystemUser = true;
              };
              systemd.services.perlsub = {
                after = [ "network.target" ];
                requires = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    ExecStart = "${self.defaultPackage.${system}}/bin/perlsub";
                    EnvironmentFile = cfg.envFile;
                    Environment = envString;
                    User = "perlsub";
                    Group = "nogroup";
                };
              };
            };
          };

        devShell = pkgs.mkShell ({
          buildInputs = [
            rust
            pkgs.rust-analyzer
          ];
          RUST_LOG = "info";
          DB_PATH = "db";
        } // envVars);
      }
    );
}
