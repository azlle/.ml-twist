{
  description = "❄️ Emacs configuration with enhanced reproducibility using Twist.nix.";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    emacs-overlay.url = "github:nix-community/emacs-overlay";

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

    twist.url = "git+https://upd.dev/Azlle/twist.nix";
    org-babel.url = "git+https://upd.dev/Azlle/org-babel";
  };

  outputs =
    {
      self,
      nixpkgs,
      emacs-overlay,
      ...
    }@inputs:

    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          emacs-overlay.overlays.default
          inputs.org-babel.overlays.default
        ];
      };

      profile = {
        lockDir = ./lock;
        earlyInitFile = (pkgs.tangleOrgBabelFile "early-init.el" ./early-init.org {});
        initFiles = [ (pkgs.tangleOrgBabelFile "init.el" ./emacs-config.org {}) ];
        exportManifest = true;
        emacsPackage = pkgs.emacs-git-pgtk;
      };

      # lib.makeEnvはEmacsの環境構築用の関数らしい
      package = inputs.twist.lib.makeEnv {
        inherit pkgs;

        # (emacsProfile)と置いておくとemacsProfile.lockDirではなくlockDirとしてinheritできるらしい
        # lib.makeEnvではearlyInitFileを使わないのでinheritしてはいけないですよ(一敗)
        inherit (profile) emacsPackage lockDir initFiles exportManifest;

        registries = import ./nix/registries.nix {
          inherit inputs;
          inherit (profile) emacsPackage;
        } ++ [ ];
      };

      defaultWrapper = pkgs.callPackage ./nix/tmpInitDirWrapper.nix { } {
        emacsEnv = package;
        inherit (profile) initFiles earlyInitFile;
        assetsDir = ./assets;
        # snippetsDir = ./snippets;
        manifestFile = package.emacsWrapper.elispManifestPath;
      };

    in {
      packages.${system}.default = package;
      apps.${system} = package.makeApps { lockDirName = "lock"; }
      // {
        default = {
          type = "app";
          program = "${defaultWrapper}/bin/emacs-twist";
        };
      };

      homeModules.twist = { lib, ... }: {
        imports = [
          inputs.twist.homeModules.emacs-twist
        ];

        programs.emacs-twist = {
          config = lib.mkDefault package;
          earlyInitFile = lib.mkDefault profile.earlyInitFile;
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
}
