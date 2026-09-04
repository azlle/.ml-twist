{
  description = "❄️ Emacs configuration with enhanced reproducibility using Twist.nix.";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    emacs-overlay.url = "github:nix-community/emacs-overlay";

    twist.url = "github:emacs-twist/twist.nix";
    org-babel.url = "github:emacs-twist/org-babel";

    elpa = {
      url = "github:elpa-mirrors/elpa";
      flake = false;
    };

    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };

    nongnu = {
      url = "github:elpa-mirrors/nongnu";
      flake = false;
    };

    epkgs = {
      url = "github:emacsmirror/epkgs";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, nixpkgs, flake-parts, emacs-overlay, ... }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem =
        { system, lib, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              emacs-overlay.overlays.default
              inputs.org-babel.overlays.default
            ];
          };

          profile = {
            lockDir = ./lock;
            earlyInitFile = pkgs.tangleOrgBabelFile "early-init.el" ./early-init.org { };
            initFiles = [ (pkgs.tangleOrgBabelFile "init.el" ./emacs-config.org { }) ];
            exportManifest = true;
            emacsPackage = pkgs.emacs-git-pgtk;
          };

          package = inputs.twist.lib.makeEnv {
            inherit pkgs;
            inherit (profile) emacsPackage lockDir initFiles exportManifest;

            # use-package ではなく setup.el を使うので、パッケージの抽出も
            # (:package NAME) を読むパーサに切り替える
            initParser = inputs.twist.lib.parseSetup { inherit lib; } { };

            # setup 自身は setup で宣言できないため明示的に足す
            extraPackages = [ "setup" ];

            registries = import ./nix/registries.nix {
              inherit inputs;
              inherit (profile) emacsPackage;
            } ++ [ ];
          };

          defaultWrapper = pkgs.callPackage ./nix/tmpInitDirWrapper.nix { } {
            emacsEnv = package;
            inherit (profile) initFiles earlyInitFile;
            assetsDir = ./assets;
            manifestFile = package.emacsWrapper.elispManifestPath;
          };
        in
        {
          packages.default = package;
          # home-manager モジュール側から拾えるように earlyInitFile も出力しておく
          packages.earlyInitFile = profile.earlyInitFile;

          apps = package.makeApps { lockDirName = "lock"; } // {
            default = {
              type = "app";
              program = "${defaultWrapper}/bin/emacs-twist";
            };
          };
        };

      flake = {
        homeModules.twist = { lib, pkgs, ... }: {
          imports = [
            inputs.twist.homeModules.emacs-twist
          ];

          programs.emacs-twist = {
            config = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
            earlyInitFile = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.earlyInitFile;
            createManifestFile = lib.mkDefault true;
          };

          home.file = {
            ".config/emacs/assets/".source = ./assets;
          };

          home.packages =
            with pkgs;
            [
              adwaita-icon-theme
              adwaita-icon-theme-legacy
              ffmpeg
              gcc
              skkDictionaries.l
              vips
              wl-clipboard
            ];
        };
      };
    };
}
